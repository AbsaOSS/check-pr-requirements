---
title: "Change Integration & Versioning"
area: management
tags:
  - repository
  - branching
  - ci-cd
  - delivery
roles:
  - developers
  - tech-leads
  - devops
  - product-owners
type: standard
last_review: 2025-11-06
nav_path: governance/software-delivery/change-integration.md
status: approved
description: "Defines the Change Integration & Versioning conventions and standards expected across CPS projects. This chapter defines the principles of how we structure branches, review and merge code, assign versions, and prepare releases, so that our main line remains continuously."
author: "@HuvarVer"
---
# Change Integration & Versioning

This chapter defines the principles of how we structure branches, review and merge code, assign versions, and prepare
releases, so that our main line remains continuously shippable. It clarifies the intent and scope of our branching
approach (working, main, and support branches), the minimum expectations for Pull Requests (content, checks,
and approvals), and the rationale behind our merge policy.
It also outlines how we think about release management and versioning, and summarizes the end-to-end release path
from code change to published artifact.
The body of this chapter provides concrete conventions and examples that teams can adopt or tailor while staying aligned
with these core practices.

## Branch Strategy

In CPS projects, we use a simplified GitHub flow as a branching strategy, i.e. short-term working branches
that are merged directly into the main branch, which is kept permanently releasable.<br>
`Release` and `Support` branches are used only exceptionally in specific cases, which are described below.

![single_main_branch_strategy.png](single_main_branch_strategy.png)
_Figure: Single main branch strategy._

> [!NOTE]
>
> - Setting up branch protection is described in the [Rulesets chapter](../security/rulesets.md).
>

### Branch Types

- *Main Branch*:
    - is the only permanent branch and must remain in a continuously shippable (always releasable) state.
    - _The name of this main branch is not clearly specified, on some projects it is_ `master` _on others_ `main`.
- *Working Branch*:
    - The purpose of these branches is to collect changes related to a single feature or fix.
        - Each working branch should be linked to a ticket whose number is given in the name of the branch.
        - Rest of the branch name should shortly describe the purpose in `kebab-cased` title.
        - Example: `feature/123-user-login`
- *Temporary Branch*:
    - `support/*` and `release/*` are time-bounded branches used to bridge periods when a single main branch
  isn’t sufficient.
    - It is used to stabilize a pending release, hotfixes or maintain a supported version line while new changes continue
  on main. This is why this type of branch should be protected in a similar way to the main branch (see [Rulesets](../security/rulesets.md)).

> [!NOTE]
>
> - *Git Branch & Commit Conventions*
>     - How to name branches: [Name convention](../../tooling/git/index.md#branch-naming)
>     - How to write commit messages: [Branch structure](../../tooling/git/index.md#writing-commit-messages)
>

### Pull Requests

- Pull Request (PR) is a proposal to merge changes from one branch into another, in our case *from working branch to
  the main branch*.
- A PR provides a structured place for:
    - _Code reviews_
    - _Discussion_
    - _Automated checks_
- A robust PR process ensures code quality, clarity, and traceability before changes are integrated.

**Goals of our PR process:**

- **Consistency**:
    - Ensure every change goes through a consistent review and testing process.
- **Clarity**:
    - Make it clear why changes were made so future readers and reviewers understand context.
- **Collaboration**:
    - Encourage team discussion and shared ownership of the codebase.

### PR Creation

When creating a PR, provide all information needed for an efficient review and release traceability.

- **Name**:
    - Use a brief and actionable title.
    - Recommended format for continuity with the issue tracker:
        - `#(issue number): (Issue title)`
        - Alternative accepted format: `{issue_number} - {issue_title}`
- **Scope**:
    - Describe what problem the PR solves or what feature it adds.
    - Explain the impact of the change.
    - If the change is UI/UX related, include screenshots or GIFs.
- **Release Notes**:
    - Summarize key changes in user-focused language.
    - Use past tense.
    - Describe what changed from user perspective.
        - Use: Now it's possible to have CSV file as input.
        - NOT use: Refactored User class constructor.
- **Related Issues**:
    - Link relevant issues or documentation.
    - Use automatic closing keywords when appropriate:
        - `Closes #issue_number` for features.
        - `Fixes #issue_number` for bugs.

*PR Content Example:*

```markdown
## Overview

## Release Notes
- TBD: Fixed the wrong placement of the submit button.
- TBD: Added the ability to sort the dataset.

## Related
Closes #issue_number
```

_This format of PR content is compatible with [Release Note Generator](https://github.com/AbsaOSS/generate-release-notes)_
or [Release Notes Presence Check](https://github.com/AbsaOSS/release-notes-presence-check).

### PR Review

Each PR should be reviewed by at least one other team member.

- In an edge case where no additional reviewer is available, self-approval is acceptable.
- For small projects, one reviewer is enough.
- For larger projects, at least two reviewers are recommended.
- [`CODEOWNERS`](../security/application_security_strategy.md#codeowners) are always
  automatically listed as reviewers for relevant project scope.

**How to conduct a review:**

- Review carefully; do not rush.
- Review in chunks. If a PR is too large, ask the author to split it.
- Test changes locally when possible.

**What to look for in review:**

- Code correctness and best practices.
- Consistency with project coding standards.
- Adequate test coverage for the proposed change.

**Giving feedback:**

- Be specific and transparent in comments.
- Keep feedback constructive.
- When uncertain, prefer asking questions over making assumptions.

**Checkers:**

- Mandatory automated checks must pass before merge into the default branch.

### Merging PRs

We use `Squash & Merge` exclusively to keep commit history clean and maintain easier auditability.

**Best practice before merge:**

- Review commit messages and keep only relevant information in the final squashed commit.

## Release Management

Release management is the management of when and what we release, determines the cadence, scope.<br>
The delivery method is then addressed in the [Delivery model](delivery-model.md).

### Versioning

- To maintain clarity about which changes belong to which version, tags are used:
    - example: `v1.0.3`
- Chapter with information about `tags`: [How to use the tags](../../tooling/git/index.md#tagging-best-practices)

### Hotfixes

- *Latest deploy is similar to actual main branch:*
    - Temporary hotfix branch & PR pointing back to main branch.
- *Fixing an older state of the project:*
    - _note:_ `PROD` _is rarely deployed against the most recent main branch._
    - Checkout the commit/tag you want to make hotfix.
    - Create new hotfix branch `support/1.0.4` or `release/1.0.4`.
    - Keep the changes in this new long-lived branch.
