# Changelog

## Unreleased

### Behaviour changes

Existing workflows keep working; these changes can alter results for some PRs or configurations:

- **Issue reference** matching is stricter: keywords must start a word (`prefix #12` no longer counts as `fix #12`), URL fragments, HTML entities, identifiers like `C#10` and hex colours are not references, and `issue-reference-require-keyword` only searches the PR body (#38).
- **PR data inputs default to the `pull_request` event.** `files-changed` no longer defaults to `0`, so an unwired `check-pr-size` now checks the real file count instead of always passing (#40).
- **Toggles and boolean inputs accept any letter case** (`True` now enables a check), and invalid configuration fails the job as `⚠️ Error` instead of being ignored or blamed on the PR (#41).
- **Release notes** are a row of the summary table and included in `pass-count`/`fail-count`/`total-count` (#39).
- **Label and actor matching ignores case** for `required-labels`, `skip-labels` and `skip-actors` (#43).
- **Failed checks emit annotations** by default; set `annotations: "false"` to turn them off (#47).

### Added

- `branch-ticket-pattern` and "How to fix" guidance in the summary (#27, #29).
- `skip-actors` / `skip-labels` bypass for bot and exempt PRs (#32).
- Nested branch names (`dependabot/github_actions/...`, `feature/a/b`) pass the default `branch-pattern` (#37).
- Outputs `skipped`, `skip-reason` (#44), `warn-count` (#48), `failed-checks` and `summary` (#47).
- `description-ignore-comments` and `description-require-section-content` (#42).
- `title-require-scope`, `title-max-length` and specific title failure reasons (#50).
- `max-lines-changed` with `additions`/`deletions` inputs (#49).
- `warn-checks` for non-blocking checks (#48).
- `comment-on-failure` sticky PR comment (#47).
- Floating major tag (`v0`) moved on each release (#52).

### Internal

- Bypass logic lives only in `check.sh` (#44); defaults are shared via `checks/defaults.sh` and tests are auto-discovered (#45).
- Workflow commands are stopped while PR-controlled text is logged, and scripts run via `$GITHUB_ACTION_PATH` (#51).

## v0.2.0

- Configurable rules aligned with the ABSA git/PR guidelines: title formats, required description sections, keyword issue references, branch tickets, target branch globs (#24).
- Security hardening of the check scripts, step summary and `GITHUB_OUTPUT` writing; lint and test CI.

## v0.1.0

- Initial release.
