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
      rescue StandardError
        nil
      end

      def permission_denied(message)
        target = extract_object(message, /permission denied for (?:database|schema|table|relation|view) "?([\w.]+)"?/)
        kind = extract_object(message, /permission denied for (database|schema|table|relation|view)/)

        hint = if kind && target
          case kind
          when "database" then "GRANT CONNECT ON DATABASE #{target} TO <role>;"
          when "schema"   then "GRANT USAGE ON SCHEMA #{target} TO <role>;"
          when "table", "relation", "view" then "GRANT SELECT ON #{target} TO <role>;"
          end
        end

        {
          title: "Permission denied",
          detail: kind && target ? "The connecting role does not have the required privilege on #{kind} \"#{target}\"." : "The connecting role lacks the required privilege.",
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
