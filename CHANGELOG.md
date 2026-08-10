# Changelog

All notable changes to this skills library. Projects that want to pin rather
than always track `main` should reference a tag here — see "Versioning &
pinning" in README.md.

## v1.1.0

- Added `frappe-decision-ladder` skill: config-before-code ladder, diff
  review / whole-app audit / full best-practices sweep workflows, a
  per-app decision-log mechanism, and a worked example for every rung.
- Added `skills/frappe-decision-ladder/hooks/frappe_ladder_check.py`, a
  deterministic `PostToolUse` hook companion that runs a subset of the
  ladder's checks automatically on every Frappe app file edit, plus an
  automated test suite (`test_frappe_ladder_check.py`) for it.
- Added `verify-install.sh`, a doctor script that checks every registered
  project's symlinks and memory-file includes are actually wired, instead
  of failing silently.
- Added `bitbucket-pipelines.yml` running the hook's test suite on every
  push and pull request.

## v1.0.0

- Initial skill set: doctype-patterns, frappe-core-database,
  frappe-core-permissions, frappe-impl-reports, frappe-impl-ui-components,
  frappe-syntax-clientscripts, frappe-syntax-controllers, frappe-syntax-hooks,
  frappe-syntax-hooks-events, frappe-syntax-scheduler,
  frappe-syntax-serverscripts, frappe-syntax-whitelisted.
- `install-skills.sh` multi-tool installer (Claude/Kiro/AmazonQ) with
  project registry and `.gitignore` handling.
