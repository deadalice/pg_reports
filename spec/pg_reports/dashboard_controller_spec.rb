# frozen_string_literal: true

require "spec_helper"
require "action_controller"
require "pg"

# Load the controller directly for unit testing.
# Full request specs require a host Rails app and live at spec/requests/.
require Pathname.new(__dir__).join("..", "..", "app", "controllers", "pg_reports", "dashboard_controller.rb").realpath.to_s

RSpec.describe PgReports::DashboardController do
  subject(:controller) { described_class.new }

  let(:registry) { PgReports.connection_registry }

  around do |example|
    registry.reset!
    registry.register(:primary, host: "h", database: "primary_db")
    example.run
    registry.reset!
  end

  def stub_selection(selected_target:, selected_database:, target_default_database: "primary_db")
    controller.instance_variable_set(:@selected_target, selected_target)
    controller.instance_variable_set(:@selected_database, selected_database)
    controller.instance_variable_set(:@target_default_database, target_default_database)
  end

  describe "#on_primary_default_database?" do
    it "is true when selection points at the primary's default DB" do
      stub_selection(selected_target: :primary, selected_database: "primary_db")
      expect(controller.send(:on_primary_default_database?)).to be true
    end

    it "is false when a non-default database is selected on primary" do
      stub_selection(selected_target: :primary, selected_database: "logs")
      expect(controller.send(:on_primary_default_database?)).to be false
    end

    it "is false when a non-primary target is selected" do
      registry.register(:analytics, host: "h", database: "warehouse")
      stub_selection(selected_target: :analytics, selected_database: "warehouse")
      expect(controller.send(:on_primary_default_database?)).to be false
    end

    it "short-circuits to true when no target_default_database is known" do
      stub_selection(selected_target: :primary, selected_database: nil, target_default_database: nil)
      expect(controller.send(:on_primary_default_database?)).to be true
    end
  end

  describe "#category_disabled_reason" do
    it "returns nil for an unconstrained category regardless of selection" do
      stub_selection(selected_target: :primary, selected_database: "logs")

      expect(controller.send(:category_disabled_reason, :queries)).to be_nil
      expect(controller.send(:category_disabled_reason, :indexes)).to be_nil
      expect(controller.send(:category_disabled_reason, :tables)).to be_nil
    end

    it "returns nil for schema_analysis when on primary's default DB" do
      stub_selection(selected_target: :primary, selected_database: "primary_db")

      expect(controller.send(:category_disabled_reason, :schema_analysis)).to be_nil
    end

    it "returns a localized message for schema_analysis on a non-default DB" do
      stub_selection(selected_target: :primary, selected_database: "logs")

      reason = controller.send(:category_disabled_reason, :schema_analysis)
      expect(reason).to be_a(String)
      expect(reason).to include("primary")
    end

    it "returns a localized message for schema_analysis on a non-primary target" do
      registry.register(:analytics, host: "h", database: "warehouse")
      stub_selection(selected_target: :analytics, selected_database: "warehouse")

      reason = controller.send(:category_disabled_reason, :schema_analysis)
      expect(reason).to be_a(String)
    end

    context "in standalone mode" do
      around do |example|
        PgReports.config.standalone = true
        example.run
        PgReports.config.standalone = false
      end

      it "disables schema_analysis even on the primary's default DB" do
        stub_selection(selected_target: :primary, selected_database: "primary_db")

        reason = controller.send(:category_disabled_reason, :schema_analysis)
        expect(reason).to be_a(String)
        expect(reason).to include("standalone")
      end

      it "still returns nil for unconstrained categories" do
        stub_selection(selected_target: :primary, selected_database: "primary_db")

        expect(controller.send(:category_disabled_reason, :queries)).to be_nil
        expect(controller.send(:category_disabled_reason, :tables)).to be_nil
      end
    end
  end

  describe "#category_disabled?" do
    it "is false when category_disabled_reason is nil" do
      stub_selection(selected_target: :primary, selected_database: "primary_db")
      expect(controller.send(:category_disabled?, :schema_analysis)).to be false
    end

    it "is true when category_disabled_reason is present" do
      stub_selection(selected_target: :primary, selected_database: "logs")
      expect(controller.send(:category_disabled?, :schema_analysis)).to be true
    end
  end

  describe "#execute_report" do
    it "raises ArgumentError when the category is gated for the current selection" do
      stub_selection(selected_target: :primary, selected_database: "logs")

      expect {
        controller.send(:execute_report, :schema_analysis, :missing_validations)
      }.to raise_error(ArgumentError, /primary database/)
    end

    it "raises ArgumentError for unknown categories" do
      stub_selection(selected_target: :primary, selected_database: "primary_db")

      expect {
        controller.send(:execute_report, :nope, :anything)
      }.to raise_error(ArgumentError, /Unknown category/)
    end

    it "raises ArgumentError for unknown reports inside a known category" do
      stub_selection(selected_target: :primary, selected_database: "primary_db")

      expect {
        controller.send(:execute_report, :system, :nope)
      }.to raise_error(ArgumentError, /Unknown report/)
    end
  end

  describe "session-mutating actions" do
    let(:session) { {} }

    before do
      allow(controller).to receive(:session).and_return(session)
      allow(controller).to receive(:redirect_back)
      # root_path is a Rails route helper; not generated in this isolated unit
      # test environment. Define a stub on the singleton so the call site
      # (`fallback_location: root_path`) evaluates without NameError.
      def controller.root_path
        "/"
      end
    end

    describe "#switch_database" do
      before do
        # In a real request `resolve_database_selection` populates this; we set
        # it directly here since we're invoking the action method in isolation.
        controller.instance_variable_set(:@available_databases, [
          {"name" => "primary_db"},
          {"name" => "logs"}
        ])
      end

      it "stores a valid database name in session" do
        allow(controller).to receive(:params).and_return(database: "logs")

        controller.switch_database

        expect(session[:pg_reports_database]).to eq("logs")
      end

      it "ignores an invalid database name" do
        allow(controller).to receive(:params).and_return(database: "does_not_exist")

        controller.switch_database

        expect(session).not_to have_key(:pg_reports_database)
      end

      it "clears session when an empty value is passed" do
        session[:pg_reports_database] = "logs"
        allow(controller).to receive(:params).and_return(database: "")

        controller.switch_database

        expect(session).not_to have_key(:pg_reports_database)
      end

      it "redirects back" do
        allow(controller).to receive(:params).and_return(database: "logs")
        expect(controller).to receive(:redirect_back).with(fallback_location: "/")

        controller.switch_database
      end
    end

    describe "#switch_target" do
      before do
        registry.register(:analytics, host: "h", database: "warehouse")
      end

      it "stores a known target in session" do
        allow(controller).to receive(:params).and_return(target: "analytics")

        controller.switch_target

        expect(session[:pg_reports_target]).to eq("analytics")
      end

      it "rejects an unknown target name" do
        allow(controller).to receive(:params).and_return(target: "missing")

        controller.switch_target

        expect(session).not_to have_key(:pg_reports_target)
      end

      it "resets the database choice when target changes — each target has its own DB list" do
        session[:pg_reports_database] = "warehouse"
        allow(controller).to receive(:params).and_return(target: "analytics")

        controller.switch_target

        expect(session).not_to have_key(:pg_reports_database)
      end

      it "clears both target and database when an empty value is passed" do
        session[:pg_reports_target] = "analytics"
        session[:pg_reports_database] = "warehouse"
        allow(controller).to receive(:params).and_return(target: "")

        controller.switch_target

        expect(session).not_to have_key(:pg_reports_target)
        expect(session).not_to have_key(:pg_reports_database)
      end
    end
  end

  describe "#valid_database?" do
    it "is true when the name appears in @available_databases" do
      controller.instance_variable_set(:@available_databases, [
        {"name" => "primary_db"},
        {"name" => "logs"}
      ])

      expect(controller.send(:valid_database?, "logs")).to be true
    end

    it "is false when the name is not in the list" do
      controller.instance_variable_set(:@available_databases, [{"name" => "primary_db"}])

      expect(controller.send(:valid_database?, "missing")).to be false
    end

    it "is false when @available_databases was never populated (e.g. connection error)" do
      controller.instance_variable_set(:@available_databases, nil)

      expect(controller.send(:valid_database?, "anything")).to be false
    end
  end
end
