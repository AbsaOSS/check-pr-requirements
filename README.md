# Check PR Requirements

A configurable GitHub Action that validates pull request properties against a set of requirements. Each check can be independently enabled/disabled, making it easy to enforce only the rules that matter for your project.

## Available Checks

| Check | Default | Description |
|-------|---------|-------------|
| `check-title` | `true` | PR title follows [Conventional Commits](https://www.conventionalcommits.org/) format |
| `check-description` | `true` | PR body meets minimum length requirement |
| `check-issue-reference` | `true` | PR references a GitHub issue (`#123`, `Fixes #123`, or issue URL) |
| `check-release-notes` | `false` | PR body contains release notes section (uses [AbsaOSS/release-notes-presence-check](https://github.com/AbsaOSS/release-notes-presence-check)) |
| `check-branch-name` | `false` | Source branch follows naming convention |
| `check-pr-size` | `false` | PR does not exceed maximum file change count |
| `check-label` | `false` | PR has required labels |
| `check-target-branch` | `false` | PR targets an allowed branch |

## Usage

```yaml
name: Check PR Requirements

on:
  pull_request:
    types: [opened, synchronize, reopened, edited, labeled, unlabeled]

jobs:
  check-pr:
    runs-on: ubuntu-latest
    steps:
      - name: Check PR requirements
        uses: <owner>/check-pr-requirements@v1
        with:
          pr-title: ${{ github.event.pull_request.title }}
          pr-body: ${{ github.event.pull_request.body }}
          pr-branch: ${{ github.event.pull_request.head.ref }}
          pr-number: ${{ github.event.pull_request.number }}
          target-branch: ${{ github.event.pull_request.base.ref }}
          files-changed: ${{ github.event.pull_request.changed_files }}
          github-token: ${{ secrets.GITHUB_TOKEN }}
          check-title: "true"
          check-description: "true"
          check-issue-reference: "true"
          check-release-notes: "true"
```

### Minimal Configuration

Only check what you need:

```yaml
- uses: <owner>/check-pr-requirements@v1
  with:
    pr-title: ${{ github.event.pull_request.title }}
    check-title: "true"
    check-description: "false"
    check-issue-reference: "false"
```

## Inputs

### PR Data

| Input | Required | Description |
|-------|----------|-------------|
| `pr-title` | Yes | Pull request title |
| `pr-body` | No | Pull request body/description |
| `pr-branch` | No | Source branch name |
| `pr-number` | No | Pull request number |
| `target-branch` | No | Target branch name |
| `files-changed` | No | Number of files changed |
| `labels` | No | Comma-separated list of PR labels |
| `github-token` | No | GitHub token (required for release notes check) |

### Check Configuration

| Input | Default | Description |
|-------|---------|-------------|
| `title-types` | `feat,fix,docs,style,refactor,perf,test,build,ci,chore,revert` | Allowed conventional commit types |
| `title-scopes` | *(empty = any)* | Allowed scopes |
| `description-min-length` | `20` | Minimum description character count |
| `branch-pattern` | `^(feature\|bugfix\|hotfix\|release\|chore\|docs\|ci\|dependabot)/[a-zA-Z0-9._-]+$` | Branch name regex |
| `max-files-changed` | `50` | Maximum files changed |
| `required-labels` | *(empty = any label)* | Required label names |
| `allowed-target-branches` | `main,master` | Allowed target branches |
| `release-notes-tag` | `## [Rr]elease [Nn]otes` | Release notes section header pattern |
| `release-notes-skip-labels` | `no RN` | Labels that skip release notes check |
| `release-notes-skip-placeholders` | `TBD` | Placeholders indicating missing notes |

## Outputs

| Output | Description |
|--------|-------------|
| `result` | `pass` or `fail` |
| `pass-count` | Number of checks passed |
| `fail-count` | Number of checks failed |
| `total-count` | Total checks executed |

## Adding a New Check

1. Create `checks/my_check.sh` — reads `INPUT_*` env vars, prints `pass` or `fail: reason`, exits 0 or 1
2. Add entry to `REGISTRY` array in `check.sh`
3. Add inputs to `action.yml` (toggle + config)
4. Add env mapping in `action.yml` composite step
5. Create `tests/test_my_check.sh`
6. Add test file to `TEST_FILES` array in `tests/run_tests.sh`

## License

Apache License 2.0 — see [LICENSE](LICENSE).
