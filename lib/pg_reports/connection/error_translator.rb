# frozen_string_literal: true

module PgReports
  module Connection
    # Translates raw PG / ActiveRecord exceptions into human-readable messages
    # with concrete remediation hints (typically a GRANT statement).
    #
    # Usage:
    #   PgReports::Connection::ErrorTranslator.translate(error)
    #   # => { title: "...", detail: "...", hint: "GRANT ...", code: "42501" }
    module ErrorTranslator
      # Relations the reports read that are supplied by an extension rather than
      # by core PostgreSQL. Used to turn "relation X does not exist" into the
      # actionable "extension Y isn't installed here".
      EXTENSION_RELATIONS = {
        "pg_stat_statements" => "pg_stat_statements",
        "pg_stat_statements_info" => "pg_stat_statements",
        "pgstattuple" => "pgstattuple",
        "pg_buffercache" => "pg_buffercache"
      }.freeze

      module_function

      # Returns a Hash with :title, :detail, :hint, :code, :raw_message.
      # The shape is suitable for rendering in the dashboard.
      def translate(error)
        sqlstate = sqlstate_for(error)
        message = error.message.to_s

        info = case sqlstate
        when "42501" then permission_denied(message)
        when "3D000" then database_does_not_exist(message)
        when "28000", "28P01" then auth_failed(message)
        when "08001", "08006", "08000", "08003", "08004" then connection_refused(message)
        when "53300" then too_many_connections(message)
        when "42P01" then undefined_table(message)
        when "42883" then undefined_function(message)
        else generic(error)
        end

        info.merge(code: sqlstate, raw_message: message)
      end

      def sqlstate_for(error)
        case error
        when PG::Error
          error.result&.error_field(PG::Result::PG_DIAG_SQLSTATE)
        when ActiveRecord::StatementInvalid, ActiveRecord::ConnectionNotEstablished
          sqlstate_for(error.cause) if error.cause && !error.cause.equal?(error)
        end
      rescue
        nil
      end

      def permission_denied(message)
        target = extract_object(message, /permission denied for (?:database|schema|table|relation|view) "?([\w.]+)"?/)
        kind = extract_object(message, /permission denied for (database|schema|table|relation|view)/)

        hint = if kind && target
          case kind
          when "database" then "GRANT CONNECT ON DATABASE #{target} TO <role>;"
          when "schema" then "GRANT USAGE ON SCHEMA #{target} TO <role>;"
          when "table", "relation", "view" then "GRANT SELECT ON #{target} TO <role>;"
          end
        end

        {
          title: "Permission denied",
          detail: (kind && target) ? "The connecting role does not have the required privilege on #{kind} \"#{target}\"." : "The connecting role lacks the required privilege.",
          hint: hint
        }
      end

      def database_does_not_exist(message)
        target = extract_object(message, /database "([^"]+)" does not exist/)
        {
          title: "Database not found",
          detail: target ? "PostgreSQL has no database named \"#{target}\"." : "The requested database does not exist on this server.",
          hint: nil
        }
      end

      def auth_failed(_message)
        {
          title: "Authentication failed",
          detail: "PostgreSQL rejected the credentials for this target.",
          hint: "Verify the username/password in the target configuration; check pg_hba.conf for the connecting host."
        }
      end

      def connection_refused(_message)
        {
          title: "Cannot reach PostgreSQL",
          detail: "The server is unreachable or refused the connection.",
          hint: "Check host/port, network reachability, and that PostgreSQL is accepting connections."
        }
      end

      def too_many_connections(_message)
        {
          title: "Too many connections",
          detail: "PostgreSQL refused the connection because max_connections is reached.",
          hint: "Wait, increase max_connections, or use a connection pooler (PgBouncer)."
        }
      end

      # A report asked for a relation this database doesn't have. Almost always an
      # extension that exists on one database in the cluster but not the one
      # currently selected — extensions are per-database, the dashboard is not.
      def undefined_table(message)
        target = extract_object(message, /relation "([^"]+)" does not exist/)

        if target && EXTENSION_RELATIONS.key?(target)
          extension = EXTENSION_RELATIONS.fetch(target)
          return {
            title: "#{extension} not available",
            detail: "This report reads \"#{target}\", which does not exist on the selected database.",
            hint: "CREATE EXTENSION IF NOT EXISTS #{extension};"
          }
        end

        {
          title: "Relation not found",
          detail: target ? "The selected database has no relation named \"#{target}\"." : "The report referenced a relation that does not exist on the selected database.",
          hint: nil
        }
      end

      def undefined_function(message)
        target = extract_object(message, /function ([\w.]+)\(/)
        {
          title: "Function not found",
          detail: target ? "The selected database has no function named \"#{target}\"." : "The report called a function that does not exist on the selected database.",
          hint: "It is usually provided by an extension that is not installed on this database."
        }
      end

      def generic(error)
        {
          title: error.class.name.split("::").last,
          detail: error.message,
          hint: nil
        }
      end

      def extract_object(message, regex)
        match = message.match(regex)
        match && match[1]
      end
    end
  end
end
