# frozen_string_literal: true

PgReports::Engine.routes.draw do
  root to: "dashboard#index"

  get "live_metrics", to: "dashboard#live_metrics", as: :live_metrics

  post "enable_pg_stat_statements", to: "dashboard#enable_pg_stat_statements", as: :enable_pg_stat_statements
  post "reset_statistics", to: "dashboard#reset_statistics", as: :reset_statistics
  post "explain_analyze", to: "dashboard#explain_analyze", as: :explain_analyze
  post "execute_query", to: "dashboard#execute_query", as: :execute_query
  post "create_migration", to: "dashboard#create_migration", as: :create_migration

  # Query monitoring
  post "query_monitor/start", to: "dashboard#start_query_monitoring", as: :start_query_monitoring
  post "query_monitor/stop", to: "dashboard#stop_query_monitoring", as: :stop_query_monitoring
  get "query_monitor/status", to: "dashboard#query_monitor_status", as: :query_monitor_status
  get "query_monitor/feed", to: "dashboard#query_monitor_feed", as: :query_monitor_feed
  get "query_monitor/history", to: "dashboard#load_query_history", as: :load_query_history
  get "query_monitor/download", to: "dashboard#download_query_monitor", as: :download_query_monitor

  get ":category/:report", to: "dashboard#show", as: :report
  post ":category/:report/run", to: "dashboard#run", as: :run_report
  post ":category/:report/telegram", to: "dashboard#send_to_telegram", as: :telegram_report
  get ":category/:report/download", to: "dashboard#download", as: :download_report
end
