# Check PR Requirements

A configurable GitHub Action that validates pull request properties against a set of requirements. Each check can be independently enabled/disabled, making it easy to enforce only the rules that matter for your project.

## Available Checks

| Check | Default | Description |
|-------|---------|-------------|
| `check-title` | `true` | PR title matches an allowed format: [Conventional Commits](https://www.conventionalcommits.org/), issue-number prefix (`#123: Title`), or custom regex |
| `check-description` | `true` | PR body meets minimum length and contains required sections |
| `check-issue-reference` | `true` | PR references a GitHub issue (`#123`, `org/repo#123`, `Fixes #123`, issue URL) or Azure Boards work item (`AB#12345`) |
| `check-release-notes` | `false` | PR body contains release notes section (uses [AbsaOSS/release-notes-presence-check](https://github.com/AbsaOSS/release-notes-presence-check)); its result is part of the summary table and counts |
| `check-branch-name` | `false` | Source branch follows naming convention |
| `check-pr-size` | `false` | PR does not exceed maximum file change count and, optionally, changed line count |
| `check-label` | `false` | PR has required labels |
| `check-target-branch` | `false` | PR targets an allowed branch |

## Usage

```yaml
name: Check PR Requirements

on:
  pull_request:
    types: [opened, synchronize, reopened, edited, labeled, unlabeled]

permissions:
  contents: read
  pull-requests: read

jobs:
  check-pr:
    runs-on: ubuntu-latest
    steps:
      - name: Check PR requirements
        uses: AbsaOSS/check-pr-requirements@v0.1.0
        with:
          check-title: "true"
          check-description: "true"
          check-issue-reference: "true"
          check-release-notes: "true"
```

### Minimal Configuration

Only check what you need:

```yaml
- uses: AbsaOSS/check-pr-requirements@v0.1.0
  with:
    check-title: "true"
    check-description: "false"
    check-issue-reference: "false"
```

## Inputs

### PR Data

PR data is read from the `pull_request` event by default, so these inputs are only needed to override it (e.g. on other event types).

| Input | Default | Description |
|-------|---------|-------------|
| `pr-title` | `github.event.pull_request.title` | Pull request title |
| `pr-body` | `github.event.pull_request.body` | Pull request body/description |
| `pr-branch` | `github.event.pull_request.head.ref` | Source branch name |
| `pr-author` | `github.event.pull_request.user.login` | PR author login (used with `skip-actors`) |
| `pr-number` | `github.event.pull_request.number` | Pull request number |
| `target-branch` | `github.event.pull_request.base.ref` | Target branch name |
| `files-changed` | `github.event.pull_request.changed_files` | Number of files changed |
| `additions` | `github.event.pull_request.additions` | Lines added (used with `max-lines-changed`) |
| `deletions` | `github.event.pull_request.deletions` | Lines deleted (used with `max-lines-changed`) |
| `labels` | PR label names joined with `,` | Comma-separated list of PR labels |
| `github-token` | `github.token` | GitHub token (used by the release notes check) |

A check whose PR data is empty fails with a message naming the missing input.

### Check Configuration

| Input | Default | Description |
|-------|---------|-------------|
| `title-formats` | `conventional` | Comma-separated allowed title formats, pass if any matches: `conventional`, `issue-number` (`#123: Title` or `123 - Title`), `custom` |
| `title-types` | `feat,fix,docs,style,refactor,perf,test,build,ci,chore,revert` | Allowed conventional commit types (`conventional` format) |
| `title-scopes` | *(empty = any)* | Allowed scopes (`conventional` format), e.g. `api,ui,auth` |
| `title-pattern` | *(empty)* | Regex the title must match (`custom` format), e.g. `^\[[A-Z]+-[0-9]+\] .+` (matches `[PROJ-123] Title`) |
| `title-require-scope` | `false` | Require a scope in `conventional` titles, e.g. `feat(api): ...` |
| `title-max-length` | *(empty = unlimited)* | Maximum title length, applied to every format (e.g. `72` for squash-merge subjects) |
| `description-min-length` | `20` | Minimum description character count |
| `description-required-sections` | *(empty = none)* | Comma-separated headings that must appear in the PR body, e.g. `## Overview,## Release Notes` |
| `description-ignore-comments` | `false` | Ignore `<!-- -->` comments (PR template hints) for the length and section checks, so an untouched template fails |
| `description-require-section-content` | `false` | Each required section must be a heading line (matched ignoring case) with text under it before the next heading of the same or higher level; comments do not count |
| `issue-reference-require-keyword` | `false` | Only keyword references in the PR body count (`Fixes #123`, `Closes AB#12345`), matching what GitHub links; bare `#123` / `AB#123` / URLs and keywords in the title are rejected |
| `branch-pattern` | `^(feature\|bugfix\|hotfix\|release\|support\|chore\|docs\|ci\|dependabot)/[a-zA-Z0-9._/-]+$` | Full branch name regex override |
| `branch-require-ticket` | `false` | Require a ticket after the branch prefix (`feature/123-user-login`) |
| `branch-ticket-pattern` | `^[^/]+/[0-9]+-` | Regex the branch must match when `branch-require-ticket` is true. Override for non-numeric schemes, e.g. `^[^/]+/[A-Z]+-[0-9]+-` for `feature/PROJ-123-...` |
| `max-files-changed` | `50` | Maximum files changed |
| `max-lines-changed` | *(empty = no limit)* | Maximum changed lines (additions + deletions); the size check fails if either limit is exceeded |
| `required-labels` | *(empty = any label)* | Required label names, matched ignoring case, e.g. `bug,enhancement` |
| `allowed-target-branches` | `main,master` | Allowed target branches; glob patterns supported (`main,support/*`) |
| `warn-checks` | *(empty = all blocking)* | Check ids whose failures are warnings that do not fail the job, e.g. `pr-size,label`. Ids: `title`, `description`, `issue-reference`, `branch-name`, `pr-size`, `label`, `target-branch`, `release-notes` |
| `skip-actors` | *(empty = no bypass)* | Comma-separated PR-author logins (ignoring case) that bypass **all** checks (needs `pr-author` wired), e.g. `dependabot[bot]` |
| `skip-labels` | *(empty = no bypass)* | Comma-separated PR labels (ignoring case) that bypass **all** checks (needs `labels` wired), e.g. `skip-checks,automated` |
| `release-notes-tag` | `## [Rr]elease [Nn]otes` | Release notes section header pattern |
| `release-notes-skip-labels` | `no RN` | Labels that skip release notes check |
| `release-notes-skip-placeholders` | `TBD` | Placeholders indicating missing notes |

Boolean inputs accept `true`/`false` in any letter case. Invalid configuration (a non-boolean toggle, a non-numeric limit, an invalid regex, an unknown title format) is reported as `⚠️ Error` with the offending input named, and fails the job, so it is not mistaken for a problem with the PR.

## Outputs

| Output | Description |
|--------|-------------|
| `result` | `pass` or `fail` |
| `pass-count` | Number of checks passed |
| `fail-count` | Number of checks failed |
| `warn-count` | Number of `warn-checks` failures reported as warnings |
| `total-count` | Total checks executed |
| `skipped` | `true` when all checks were bypassed by `skip-actors` or `skip-labels` |
| `skip-reason` | Why the checks were bypassed, e.g. `author dependabot[bot] matched skip-actors` |

### Bypass trust model

`skip-labels` lets anyone who can label PRs (triage access or higher) bypass **every** check. Use a dedicated label that is not applied by automation, and rely on branch protection reviews for PRs that carry it. `skip-actors` matches the PR author login, so wire `pr-author` to `github.event.pull_request.user.login`, not `github.actor` (the user who triggered the run).

## Adding a New Check

1. Create `checks/my_check.sh` — sources `lib.sh`, reads `INPUT_*` env vars, prints `pass` or `fail: reason`, exits 0 or 1
2. Add entry to `REGISTRY` array and a "How to fix" tip to `remediation_for` in `check.sh`
3. Add inputs to `action.yml` (toggle + config) and their env mapping in the composite step
4. Put non-trivial config defaults in `checks/defaults.sh` (`tests/test_defaults.sh` checks they match `action.yml`)
5. Create `tests/test_my_check.sh` — `tests/run_tests.sh` picks up every `tests/test_*.sh` automatically

## License

Apache License 2.0 — see [LICENSE](LICENSE).
