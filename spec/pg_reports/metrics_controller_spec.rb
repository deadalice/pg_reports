# frozen_string_literal: true

require "spec_helper"
require "action_controller"

# Load the controller directly for unit testing.
# A full request spec requires a host Rails app and lives at spec/requests/.
require Pathname.new(__dir__).join("..", "..", "app", "controllers", "pg_reports", "metrics_controller.rb").realpath.to_s

RSpec.describe PgReports::MetricsController do
  before do
    PgReports.reset_configuration!
    allow(PgReports::Grafana::Exporter).to receive(:render).and_return("# fake metrics\n")
  end

  describe "#authenticate_metrics!" do
    let(:controller) { described_class.new }

    def stub_request_with(auth_header)
      headers = {"Authorization" => auth_header}
      req = double("request", headers: headers)
      allow(controller).to receive(:request).and_return(req)
    end

    context "when token is configured" do
      before { PgReports.config.grafana_metrics_token = "s3cret" }

      it "passes when bearer token matches" do
        stub_request_with("Bearer s3cret")
        expect(controller).not_to receive(:head)

        controller.send(:authenticate_metrics!)
      end

      it "passes case-insensitively on the scheme" do
        stub_request_with("bearer s3cret")
        expect(controller).not_to receive(:head)

        controller.send(:authenticate_metrics!)
      end

      it "rejects when token is wrong" do
        stub_request_with("Bearer nope")
        expect(controller).to receive(:head).with(:unauthorized)

        controller.send(:authenticate_metrics!)
      end

      it "rejects when Authorization header is missing" do
        stub_request_with(nil)
        expect(controller).to receive(:head).with(:unauthorized)

        controller.send(:authenticate_metrics!)
      end

      it "rejects when token is blank in config and no header sent" do
        PgReports.config.grafana_metrics_token = ""
        stub_request_with(nil)
        # Filter wouldn't fire anyway since token is blank, but if invoked directly it should reject.
        expect(controller).to receive(:head).with(:unauthorized)

        controller.send(:authenticate_metrics!)
      end
    end
  end

  describe "content type constant" do
    it "uses Prometheus exposition format" do
      expect(described_class::CONTENT_TYPE).to include("text/plain")
      expect(described_class::CONTENT_TYPE).to include("version=0.0.4")
    end
  end
end
