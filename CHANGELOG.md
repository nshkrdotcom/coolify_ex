# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.4.0] - 2026-04-04

### Fixed

- Normalize latest-deployment responses that return `deployment_uuid`
  instead of `uuid`.
- Fix `CoolifyEx.fetch_latest_application_deployment/3` for Coolify payloads
  that only expose `deployment_uuid`.
- Fix `mix coolify.status --latest` when the latest deployment lookup returns
  `deployment_uuid` fields.

### Changed

- Replace the static README release badge with a live Hex.pm version badge.
- Refresh installation snippets and getting-started examples for the current
  `0.4.x` release line.

## [0.3.0] - 2026-03-28

### Added

- Add deployment listing and latest-deployment lookup by manifest project or
  explicit app UUID.
- Add `CoolifyEx.list_application_deployments/3` and
  `CoolifyEx.fetch_latest_application_deployment/3`.
- Add `mix coolify.deployments` and `mix coolify.latest`.
- Extend `mix coolify.status` and `mix coolify.logs` with `--latest` project
  lookup support.
- Add deployment summary fields for `commit_message`, `created_at`, and
  `finished_at`.

### Changed

- Normalize Coolify deployment responses into a richer `CoolifyEx.Deployment`
  struct for both UUID fetches and application deployment listings.
- Improve task-level error messages for empty deployment history and HTTP/API
  failures.
- Update README and guides to document the full operator flow without manual
  `curl`.

## [0.2.0] - 2026-03-27

### Added

- Add `CoolifyEx.ApplicationLogs` with manifest-aware fetch and follow support for runtime application logs.
- Add `CoolifyEx.fetch_application_logs/3` and `CoolifyEx.follow_application_logs/4`.
- Add `mix coolify.app_logs` for runtime log inspection by manifest project name.

### Changed

- Update README and guides to document deployment logs versus runtime application logs.
- Include `guides/` and `assets/` in the published package metadata.

## [0.1.0] - 2026-03-27

### Added

- Initial release.
