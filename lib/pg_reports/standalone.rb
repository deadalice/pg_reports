# frozen_string_literal: true

require "securerandom"

module PgReports
  # Runs the dashboard as a self-contained application, without a host Rails app.
  #
  # It boots a minimal Rails::Application that mounts PgReports::Engine and points
  # ActiveRecord::Base at a PostgreSQL database, then serves it over HTTP. This is
  # what powers the `pg_reports server` executable and the `pg_reports:server`
  # rake task, so the project can be launched straight from the gem's root folder.
  #
  # Dependency note: this relies only on gems already pulled in transitively by
  # the gem's runtime deps (rack via actionpack, rackup via railties). The actual
  # web server (puma / webrick) is resolved at run time and is NOT a hard
  # dependency — installed-gem users bring their own.
  module Standalone
    extend self

    DEFAULT_PORT = 4000
    DEFAULT_HOST = "127.0.0.1"
    DEFAULT_MOUNT = "/"

    # Rack handlers tried, in order, when none is named explicitly.
    CANDIDATE_SERVERS = %w[puma webrick].freeze

    # Config files auto-loaded (first that exists), relative to the working
    # directory, when no explicit --config path is given.
    DEFAULT_CONFIG_FILES = %w[pg_reports.rb config/pg_reports.rb].freeze

    class ServerUnavailable < PgReports::Error; end

    # Boot the app and start a (blocking) web server.
    #
    # @param port [Integer]
    # @param host [String]
    # @param mount_path [String] where the engine is mounted (default "/")
    # @param database_url [String, nil] explicit connection URL; otherwise resolved
    #   from DATABASE_URL or libpq-style PG* env vars
    # @param server [String, nil] Rack handler name to force (e.g. "puma")
    # @param config_file [String, nil] path to a Ruby config file that calls
    #   `PgReports.configure`; auto-detected from DEFAULT_CONFIG_FILES otherwise
    # @param overrides [Hash] per-setting overrides applied last (from CLI flags);
    #   nil values are ignored. Keys are Configuration attribute names.
    def run(port: DEFAULT_PORT, host: DEFAULT_HOST, mount_path: DEFAULT_MOUNT,
      database_url: nil, server: nil, config_file: nil, overrides: {})
      # Rails' ActiveRecord railtie reads the connection from DATABASE_URL when no
      # config/database.yml exists — so we route our resolved connection through
      # it. The connection registry then auto-registers it as the :primary target,
      # and database switching / multi-cluster all work unchanged.
      ENV["DATABASE_URL"] = connection_url(database_url)

      # Mark this process as standalone so the dashboard can hide reports that
      # only make sense with a host app (e.g. Schema Analysis, which introspects
      # the host application's ActiveRecord models — there are none here).
      PgReports.config.standalone = true

      # Layer settings on top of the ENV-derived defaults: config file first, then
      # explicit CLI overrides win.
      apply_configuration(config_file: config_file, overrides: overrides)

      app = build_application(mount_path)
      app.initialize!
      verify_connection!

      handler_name, handler = resolve_server(server)
      banner(host: host, port: port, server: handler_name)
      handler.run(app, Host: host, Port: port)
    end

    # Resolve the connection URL. Priority: explicit url > DATABASE_URL >
    # libpq-style PG* env vars (PGHOST/PGPORT/PGUSER/PGPASSWORD/PGDATABASE).
    def connection_url(explicit = nil)
      return explicit if explicit && !explicit.empty?
      return ENV["DATABASE_URL"] if ENV["DATABASE_URL"] && !ENV["DATABASE_URL"].empty?

      require "erb"
      user = ENV["PGUSER"] || ENV["USER"]
      password = ENV["PGPASSWORD"]
      host = ENV["PGHOST"] || "localhost"
      port = ENV["PGPORT"] || 5432
      database = ENV["PGDATABASE"] || "postgres"

      userinfo = +""
      if user && !user.empty?
        userinfo << ERB::Util.url_encode(user)
        userinfo << ":#{ERB::Util.url_encode(password)}" if password && !password.empty?
        userinfo << "@"
      end

      "postgresql://#{userinfo}#{host}:#{port}/#{ERB::Util.url_encode(database)}"
    end

    private

    # Apply configuration in increasing order of precedence:
    #   ENV vars (already read when Configuration was built)
    #     < config file (full Ruby, calls PgReports.configure)
    #     < CLI overrides (individual flags)
    #
    # The config file is the escape hatch for every setting that has no dedicated
    # flag — thresholds, Telegram, Grafana favorites, even the dashboard_auth
    # proc. CLI flags cover only the handful of common security toggles.
    def apply_configuration(config_file:, overrides:)
      path = config_file || detect_config_file
      load_config_file(path) if path

      overrides.each do |key, value|
        next if value.nil? # unset flag — leave the file/ENV value in place
        PgReports.config.public_send(:"#{key}=", value)
      end
    end

    # First existing DEFAULT_CONFIG_FILES entry (relative to the working dir), or
    # nil when the user keeps no config file.
    def detect_config_file
      DEFAULT_CONFIG_FILES
        .map { |f| File.expand_path(f, Dir.pwd) }
        .find { |f| File.file?(f) }
    end

    # Evaluate a Ruby config file. A missing explicit path is an error (the user
    # asked for it); a broken file is reported with context rather than a raw
    # backtrace.
    def load_config_file(path)
      full = File.expand_path(path)
      raise PgReports::Error, "Config file not found: #{path}" unless File.file?(full)

      warn "pg_reports: loading config from #{full}"
      load full
    rescue PgReports::Error
      raise
    rescue => e
      raise PgReports::Error, "Failed to load config file #{full}: #{e.message}"
    end

    # Build (and register as Rails.application) a minimal Rails app that mounts
    # the engine. Kept intentionally small: no asset pipeline (views are inline),
    # cookie sessions for the dashboard's database selector + CSRF.
    def build_application(mount_path)
      require "rails"
      require "action_controller/railtie"
      require "active_record/railtie"
      require "tmpdir"
      # pg_reports.rb only requires the engine when Rails::Engine is already
      # defined; when loaded outside a Rails app that guard was false, so load it
      # now that the railties are present. This also registers its initializers.
      require "pg_reports/engine"

      target_mount = mount_path
      # A throwaway, empty app root. We must NOT use the gem root here — Rails
      # would then load the gem's engine config/routes.rb (and config/locales) as
      # the *application's* own, which double-loads and breaks. The engine loads
      # those itself relative to its own root; the app only needs the mount below.
      app_root = Dir.mktmpdir("pg_reports-standalone")
      at_exit { FileUtils.remove_entry(app_root, true) }

      Class.new(Rails::Application) do
        config.root = app_root
        config.eager_load = false
        config.consider_all_requests_local = true
        config.secret_key_base = ENV["SECRET_KEY_BASE"] || SecureRandom.hex(64)
        config.session_store :cookie_store, key: "_pg_reports_session"
        config.hosts.clear # local tool: don't block by Host header
        config.logger = ::Logger.new($stdout)
        config.log_level = (ENV["LOG_LEVEL"] || "info").to_sym
        config.active_support.report_deprecations = false

        routes.append do
          mount PgReports::Engine, at: target_mount, as: "pg_reports"
        end
      end
    end

    # Force an actual connection so the user gets a clear error at startup rather
    # than a 500 on the first request when the database is unreachable.
    def verify_connection!
      ActiveRecord::Base.connection
    rescue => e
      raise PgReports::Error, "Cannot connect to the database (#{ENV["DATABASE_URL"]}): #{e.message}"
    end

    # Find a usable Rack handler. Honors an explicit name, otherwise tries the
    # candidates in order and uses the first that is installed.
    def resolve_server(name)
      require "rackup"

      candidates = name ? [name] : CANDIDATE_SERVERS
      candidates.each do |candidate|
        handler = begin
          Rackup::Handler.get(candidate)
        rescue LoadError, NameError
          nil
        end
        return [candidate, handler] if handler
      end

      raise ServerUnavailable, <<~MSG.strip
        No web server found (tried: #{candidates.join(", ")}).
        Add one to run the standalone dashboard, e.g. `gem install puma`
        (or add `gem "puma"` to your Gemfile).
      MSG
    end

    def banner(host:, port:, server:)
      url_host = (host == "0.0.0.0") ? "localhost" : host
      warn "pg_reports: serving dashboard via #{server} on http://#{url_host}:#{port} (Ctrl-C to stop)"
    end
  end
end
