# frozen_string_literal: true

module PgReports
  class Engine < ::Rails::Engine
    isolate_namespace PgReports

    config.generators do |g|
      g.test_framework :rspec
    end

    # Load locales from the engine
    initializer "pg_reports.load_locales" do |app|
      config.i18n.load_path += Dir[root.join("config", "locales", "*.yml")]
    end

    initializer "pg_reports.assets" do |_app|
      # Assets are inline in views, no precompilation needed
    end

    initializer "pg_reports.append_routes" do |app|
      # Allow mounting at custom path
      app.routes.append do
        # Routes are mounted by the user in their routes.rb
      end
    end
  end
end
