# frozen_string_literal: true

module PgReports
  module Connection
    # Registry of named PostgreSQL targets.
    #
    # In a Rails app the :primary target is auto-registered on first access from
    # ActiveRecord::Base.connection_db_config — no configuration is required.
    # Additional targets can be registered explicitly via Configuration#add_target
    # for setups where the dashboard should reach databases the host app cannot.
    #
    # Current target/database is tracked in a Thread.current slot, switched via
    # PgReports.with_target / PgReports.with_database for block-scoped usage.
    class Registry
      THREAD_KEY_TARGET = :pg_reports_current_target
      THREAD_KEY_DATABASE = :pg_reports_current_database

      class UnknownTarget < PgReports::Error; end

      def initialize
        @targets = {}
        @default_name = :primary
        @auto_registered = false
        @mutex = Mutex.new
      end

      attr_reader :default_name

      def default_name=(name)
        @default_name = name.to_sym
      end

      # Register or overwrite a target.
      def register(name, spec)
        @targets[name.to_sym] = Target.new(name, spec)
      end

      # All known targets (auto-registers :primary if needed first).
      def targets
        ensure_default_registered!
        @targets.values
      end

      def target_names
        targets.map(&:name)
      end

      def target?(name)
        targets.any? { |t| t.name == name.to_sym }
      end

      def fetch(name = nil)
        ensure_default_registered!
        key = (name || current_name || @default_name).to_sym
        @targets.fetch(key) { raise UnknownTarget, "Unknown target #{key.inspect}. Known: #{@targets.keys.inspect}" }
      end

      # Resolve the AR connection to use right now (current target + database).
      # Honors PgReports.with_target / with_database thread-local context.
      def current_connection
        target = fetch(current_name)
        target.connection_for(current_database)
      end

      # Returns the target that current_connection would resolve to.
      def current_target
        fetch(current_name)
      end

      # The database name in effect for the current target.
      def current_database_name
        current_database || fetch(current_name).default_database
      end

      def current_name
        Thread.current[THREAD_KEY_TARGET]
      end

      def current_database
        Thread.current[THREAD_KEY_DATABASE]
      end

      # Switch target and/or database for the duration of the block. Semantics:
      # - target given      → switches target AND clears the database override
      #                       (the previous database belongs to the previous
      #                       target's cluster and would not be valid on a new
      #                       one). Pass `database:` explicitly to override on
      #                       the new target.
      # - target nil        → keeps the active target, switches only database.
      # - database nil      → uses the (possibly new) target's default database.
      def with_context(target: nil, database: nil)
        prev_target = Thread.current[THREAD_KEY_TARGET]
        prev_database = Thread.current[THREAD_KEY_DATABASE]

        if target
          Thread.current[THREAD_KEY_TARGET] = target.to_sym
          Thread.current[THREAD_KEY_DATABASE] = database&.to_s
        elsif database
          Thread.current[THREAD_KEY_DATABASE] = database.to_s
        end

        yield
      ensure
        Thread.current[THREAD_KEY_TARGET] = prev_target
        Thread.current[THREAD_KEY_DATABASE] = prev_database
      end

      # For tests / reload scenarios. Restores the registry to a fresh state —
      # closes all derived pools, drops all registered targets, resets
      # default_name back to :primary, and re-arms auto-registration.
      def reset!
        @mutex.synchronize do
          @targets.each_value(&:disconnect!)
          @targets.clear
          @default_name = :primary
          @auto_registered = false
        end
      end

      # Auto-discover the :primary target from ActiveRecord on first need.
      # Idempotent and thread-safe.
      def ensure_default_registered!
        return if @auto_registered
        return unless defined?(ActiveRecord::Base)

        @mutex.synchronize do
          return if @auto_registered

          unless @targets.key?(:primary)
            spec = primary_spec_from_active_record
            @targets[:primary] = Target.new(:primary, spec) if spec
          end

          @auto_registered = true
        end
      end

      private

      def primary_spec_from_active_record
        config = ActiveRecord::Base.connection_db_config
        return nil unless config

        config.configuration_hash.transform_keys(&:to_sym)
      rescue ActiveRecord::ConnectionNotEstablished
        nil
      end
    end
  end
end
