# frozen_string_literal: true

require "digest/sha2"

module PgReports
  class MetricsController < ActionController::Base
    CONTENT_TYPE = "text/plain; version=0.0.4; charset=utf-8"

    before_action :authenticate_metrics!, if: -> { PgReports.config.grafana_metrics_token.present? }

    def show
      render plain: PgReports::Grafana::Exporter.render, content_type: CONTENT_TYPE
    end

    private

    def authenticate_metrics!
      expected = PgReports.config.grafana_metrics_token.to_s
      provided = request.headers["Authorization"].to_s.sub(/\Abearer\s+/i, "")

      a = ::Digest::SHA256.digest(expected)
      b = ::Digest::SHA256.digest(provided)

      head :unauthorized unless ActiveSupport::SecurityUtils.secure_compare(a, b) && expected.present?
    end
  end
end
