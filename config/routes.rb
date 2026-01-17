# frozen_string_literal: true

PgReports::Engine.routes.draw do
  root to: "dashboard#index"

  post "enable_pg_stat_statements", to: "dashboard#enable_pg_stat_statements", as: :enable_pg_stat_statements
  post "reset_statistics", to: "dashboard#reset_statistics", as: :reset_statistics

  get ":category/:report", to: "dashboard#show", as: :report
  post ":category/:report/run", to: "dashboard#run", as: :run_report
  post ":category/:report/telegram", to: "dashboard#send_to_telegram", as: :telegram_report
  get ":category/:report/download", to: "dashboard#download", as: :download_report
end
