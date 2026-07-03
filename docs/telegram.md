# Telegram delivery

Send any report to a Telegram chat or channel — as a formatted message or a file attachment. Useful for scheduled health digests, alerting from a rake task, or pushing a report to your team on demand.

## Install the client gem

Delivery uses [`telegram-bot-ruby`](https://github.com/atipugin/telegram-bot-ruby), which is an **optional** dependency — add it only if you use Telegram:

```ruby
# Gemfile
gem "telegram-bot-ruby"
```

Without it, calling a delivery method raises with a message telling you to add the gem.

## Configure

Get a bot token from [@BotFather](https://t.me/BotFather) and your chat ID from [@userinfobot](https://t.me/userinfobot), then:

```ruby
# config/initializers/pg_reports.rb
PgReports.configure do |config|
  config.telegram_bot_token = ENV["PG_REPORTS_TELEGRAM_TOKEN"]  # "123456:ABC-DEF..."
  config.telegram_chat_id   = ENV["PG_REPORTS_TELEGRAM_CHAT_ID"] # "-1001234567890"
end
```

Both also read from the `PG_REPORTS_TELEGRAM_TOKEN` / `PG_REPORTS_TELEGRAM_CHAT_ID` environment variables by default, so setting the env vars alone is enough.

| Option | Env var | Description |
|--------|---------|-------------|
| `telegram_bot_token` | `PG_REPORTS_TELEGRAM_TOKEN` | Bot token from @BotFather |
| `telegram_chat_id` | `PG_REPORTS_TELEGRAM_CHAT_ID` | Target chat or channel ID |

## Send

```ruby
PgReports.slow_queries.send_to_telegram          # as a message
PgReports.health_report.send_to_telegram_as_file # as a file attachment
```

Reports under ~50 rows are sent as a message; larger ones are sent as a file attachment automatically when you use `send_to_telegram`. In the dashboard, the **Send to Telegram** action on any report does the same.

## Security

Report content — table rows, which may include query text and source file paths — is sent to `api.telegram.org`. Don't enable delivery in environments where report data could contain PII or secrets unless your bot and chat are appropriately scoped. See [what gets sent to Telegram](configuration.md#what-gets-sent-to-telegram) in the security model.
