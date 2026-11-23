---
title: "Git"
area: tooling
tags:
  - repository
  - tooling
  - standards
  - devops
roles:
  - developers
  - tech-leads
  - devops
technologies:
  - git
type: overview
last_review: 2025-03-19
nav_path: tooling/git.md
status: review-needed
description: "Overview of the Git section covering its scope and main topics. Establish clear naming conventions to maintain organized branches."
author: "@Zejnilovic"
---
# 📁 **Git**

## Best practices

### Branch Naming

Establish clear naming conventions to maintain organized branches. Prefixes clearly
indicate the purpose of each branch, and always include a ticket number and
descriptive text:

- feature/ for new features (e.g., feature/123-user-login)
- bugfix/ for bug fixes (e.g., bugfix/124-login-error)
- hotfix/ for critical fixes needing immediate deployment (e.g., hotfix/125-payment-crash)
- release/ for stable release versions (e.g., release/v1.2.0)

Adding Ticket Numbers

Incorporate ticket numbers from your task management system (like GitHub Issues)
into your branch names and commit messages. This practice links your commits directly
to your project management context.

Example branch name:

```text
feature/123-user-registration
```

### Writing Commit Messages

Commit messages should clearly describe what changes have been made and why,
maintaining readability and facilitating future code reviews.

#### Recommended Structure

```text
Short summary (max 50 characters)

Detailed description if necessary (max 72 characters per line).
Include context, reasoning, or consequences of the change.

Co-authored-by: Jane Doe <jane.doe@example.com>
```

**Guidelines:**

- **Subject line**: concise, imperative mood (e.g., "Add login validation")
- **Description**: Provide sufficient context and explain *why* the change was made.
- Use `Co-authored-by` tag to acknowledge contributions clearly.

### Tagging Best Practices

Tags clearly mark specific points in your repository's history, typically used for
releases.

- **Semantic Versioning:** Tag each release clearly, following semantic versioning:
`v1.2.3`
- Annotate tags with descriptive messages.
- Use annotated tags for releases (`git tag -a`).

**Example:**

```bash
git tag -a v1.2.0 -m "Release version 1.2.0 with new login feature"
```

Use tags consistently for releases, hotfixes, and milestones.

**Tag naming examples:**

- `v1.0.0`
- `v2.1.1-hotfix`
- `v2.0-beta`

### Git Stash and Pop Best Practices

Use `git stash` and `git stash pop` to temporarily save changes without committing
them when you need to switch contexts or branches:

- **Use descriptive stash messages**:

  ```bash
  git stash push -m "WIP: add user login validations"
  ```

- **View stash contents before applying:**

  ```bash
  git stash list
  ```

- **Apply changes from stash carefully:**

  ```bash
  git stash pop
  ```

  Prefer `git stash apply` when you're uncertain and want to ensure conflicts are
  resolved manually:
  
  ```bash
  git stash apply stash@{0}
  ```

- **Clear stash when no longer needed:**
  
  ```bash
  git stash drop stash@{0}
  ```

Use stashing strategically to switch tasks without losing your work, and always
clearly label stash entries.

## Git config

`git config` is a Git command for configuring repository-specific or global settings
like user identity, editor preferences, and credential management. The official Git
[documentation](https://git-scm.com/docs/git-config) provides detailed explanations of
available configuration options, including core settings (e.g., default branch names,
line endings), user settings (e.g., username, email), and advanced features like
credential storage and remote repository preferences.

Below is a set of curated
settings gathered over the years working in Absa.

### Credential Management

Cache credentials temporarily to avoid repeated login prompts:

```ini
[credential]
    helper = cache --timeout=3600
```

This caches your credentials for 1 hour (3600 seconds).

### Conditional Includes

These include paths let you define specific configurations for particular directories
or projects.
Load repository-specific settings automatically based on directory structure:

```ini
[includeIf "gitdir:/Path/To/Folder/ProjectA/"]
    path = /Path/To/Folder/ProjectA/.gitconfig_include

[includeIf "gitdir:/Path/To/Folder/absa-group/"]
    path = /Path/To/Folder/absa-group/.gitconfig_include
```

### Commit Configuration

Enhance commit details and security:

```ini
[commit]
    verbose = true        # Shows detailed diffs in the commit message editor.
    gpgSign = true        # Automatically signs commits with your GPG key.
```

### Push Behavior

Optimize pushing changes to remote repositories:

```ini
[push]
    default = simple          # Pushes only the current branch to its upstream.
    autoSetupRemote = true    # Creates remote branches automatically when pushing new branches.
    followTags = true         # Pushes associated tags automatically.
```

### Fetch Behavior

Ensure local repository stays clean and updated:

```ini
[fetch]
    prune = true          # Deletes local tracking branches that no longer exist remotely.
    pruneTags = true      # Removes tags that have been deleted remotely.
    all = true            # Fetches all branches from the remote by default.
```

⚠️ `prune` and `pruneTags` will delete local branches and tags, without asking
for consent.

### Diff and Merge Optimization

Customize diff output for clarity:

```ini
[diff]
    renames = true            # Detects renamed files.
    renamesThreshold = 50%    # Sets the threshold for rename detection.
    algorithm = patience      # Uses the patience diff algorithm for clearer diffs.
    colorMoved = default      # Highlights moved lines.
```

ℹ️ More on the topic of Patience Diff in [here](patience-diff.md)

Improve merge conflict readability:

```ini
[merge]
    conflictStyle = zdiff3     # Provides a more comprehensive context during merge conflicts.
```

ℹ️ More on the topic of zdiff3 in [here](zdiff3.md)

### General Convenience

Automatically correct common typos and reuse conflict resolutions:

```ini
[help]
    autocorrect = prompt      # Suggests corrections when you mistype a command.

[rerere]
    enabled = true            # Records resolutions to merge conflicts.
    autoUpdate = true         # Automatically updates resolutions for recurring conflicts.
```

### Line Ending Management

Standardize line endings across different operating systems:

```ini
[core]
    autocrlf = input          # Ensures consistent line endings.
```

### Pull Strategy

Maintain linear commit history:

```ini
[pull]
    rebase = true             # Rebases by default instead of merging when pulling.
```

### Performance Enhancements

For faster performance in large repositories:

```ini
[core]
    fsmonitor = true        # Monitors file system changes for faster status.
    untrackedCache = true   # Caches untracked files to speed up git status.
```

### Useful Aliases

Simplify frequent Git commands:

```ini
[alias]
    st = status -sb
    co = checkout
    br = branch
    cm = commit
    df = diff
    lg = log --oneline --graph --decorate --all
    hist = log --oneline --graph --decorate --all
```

Example usage:

```bash
git st   # Short status
git lg   # Graphical log view
```
