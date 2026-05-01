# frozen_string_literal: true

module PgReports
  module Connection
    # Represents a single named PostgreSQL target (host+credentials).
    # Holds a memoized AR-subclass-backed connection per database it has been
    # asked for, so switching between databases on the same target reuses pools.
    #
    # The :primary target wraps ActiveRecord::Base directly when accessed at its
    # default database — we don't open a parallel pool to the host app's DB.
    # For non-default databases we create an isolated AR subclass that has its
    # own pool, so the host application's pool is never affected.
    class Target
      class ConnectionFailed < PgReports::Error; end

      attr_reader :name

      def initialize(name, spec)
        @name = name.to_sym
        @spec = normalize_spec(spec)
        @pools = {} # database (string) => AR class
      end

      # Configuration hash used as a template for derived databases.
      def spec
        @spec.dup
      end

      def default_database
        @spec[:database]&.to_s
      end

      # Resolve the AR class backing the connection for `database` (nil = default).
      # Returns a class responding to `.connection` (ActiveRecord::Base or subclass).
      def ar_class_for(database = nil)
        db = (database || default_database).to_s
        raise ArgumentError, "Cannot resolve connection: target #{name.inspect} has no default database and none was given" if db.empty?

        @pools[db] ||= build_pool_class(db)
      end

      # Returns the active PG connection for `database`, opening it if needed.
      def connection_for(database = nil)
        ar_class_for(database).connection
      rescue ActiveRecord::NoDatabaseError, PG::ConnectionBad => e
        raise ConnectionFailed, "Cannot connect to #{name}/#{database || default_database}: #{e.message}"
      end

      # List all databases visible on this target's cluster (using pg_database).
      # Result rows: { "name" => String, "size" => String, "current" => Boolean }
      def list_databases(current: nil)
        rows = connection_for.exec_query(<<~SQL).to_a
          SELECT datname AS name,
                 pg_size_pretty(pg_database_size(datname)) AS size
          FROM pg_database
          WHERE datistemplate = false AND datallowconn = true
          ORDER BY datname
        SQL
        current_db = (current || default_database).to_s
        rows.each { |r| r["current"] = (r["name"].to_s == current_db) }
        rows
      end

      # Close all derived pools we own. The :primary AR::Base pool is never touched.
      def disconnect!
        @pools.each_value do |klass|
          next if klass.equal?(ActiveRecord::Base)
          klass.connection_pool.disconnect! if klass.connection_pool.connected?
        rescue
          # Best-effort cleanup
        end
        @pools.clear
      end

      private

      def normalize_spec(spec)
        hash = case spec
        when Hash
          spec.transform_keys(&:to_sym)
        when ActiveRecord::DatabaseConfigurations::HashConfig
          spec.configuration_hash.transform_keys(&:to_sym)
        else
          raise ArgumentError, "Unsupported spec type: #{spec.class}"
        end

        # Ensure adapter defaults to postgresql; we only support PG.
        hash[:adapter] ||= "postgresql"
        hash
      end

      def build_pool_class(database)
        # When asked for the primary target's default database, reuse AR::Base
        # so we don't open a parallel pool to the same DB the host app uses.
        if name == :primary && database == default_database
          return ActiveRecord::Base
        end

        klass = Class.new(ActiveRecord::Base) { self.abstract_class = true }
        const_name = "Pool_#{name}_#{database}".gsub(/\W/, "_")
        if PgReports::Connection.const_defined?(const_name, false)
          PgReports::Connection.send(:remove_const, const_name)
        end
        PgReports::Connection.const_set(const_name, klass)

        klass.establish_connection(@spec.merge(database: database))
        klass
      end
    end
  end
end
