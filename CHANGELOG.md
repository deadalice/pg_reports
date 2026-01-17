# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-01-17

### Added

- Initial release
- Query analysis module (slow, heavy, expensive queries)
- Index analysis module (unused, duplicate, invalid, missing indexes)
- Table analysis module (sizes, bloat, vacuum status)
- Connection analysis module (active connections, locks, blocking queries)
- System module (database sizes, settings, extensions)
- Web dashboard with beautiful dark theme
- Expandable table rows for full query text
- Download reports in TXT, CSV, JSON formats
- Telegram integration for sending reports
- pg_stat_statements management (enable/status check)
