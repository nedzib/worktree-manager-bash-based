# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Worktree Manager (`wtm`) is a CLI tool for managing Git worktrees in bare repositories. Published as `@jx0/wtm` on npm. Implemented as a single portable Bash script — zero runtime dependencies other than Bash and Git.

## Commands

No build step. Edit `wtm` directly and test:
```bash
./wtm help           # Verify changes
./wtm list           # Test in a wtm-managed bare repo
```

## Architecture

```
wtm                # Single Bash script — all commands and helpers included
```

**Key functions:**
- `wtm_cmd_init` — Clone repos into bare structure with `.git/` subdirectory, or adopt existing repos
- `wtm_cmd_create` — Validate bare repo, fetch from remote, create worktree, spawn interactive shell
- `wtm_cmd_checkout` — Create worktree from existing remote branch
- `wtm_cmd_list` — Parse `git worktree list --porcelain` into formatted table
- `wtm_cmd_delete` — Remove worktree safely
- `wtm_cmd_cleanup` — Detect merged branches, check for uncommitted/unpushed work, interactive selection
- `wtm_run_hook` — Run `.wtm/post_create` scripts with environment variables (`WORKTREE_DIR`, `WORKTREE_NAME`, `BASE_BRANCH`, `BARE_REPO_PATH`)

**CLI commands:**
- `wtm init <url> [path]` — Clone repo into wtm-managed bare structure with `.git/` subdirectory
- `wtm init [path]` — Adopt existing repo into wtm structure
- `wtm create <name> --from <branch> [--no-shell]` — Create worktree and spawn shell
- `wtm checkout <branch>` — Create worktree from existing remote branch
- `wtm list` — Show all worktrees
- `wtm delete <name> [--force]` — Remove worktree
- `wtm cleanup [--base <branch>] [--dry-run] [--yes]` — Find and delete merged worktrees

## Bash Patterns

Git operations use plain `git` commands:
```bash
result=$(git worktree list --porcelain 2>/dev/null)
git fetch origin "+${branch}:refs/remotes/origin/${branch}" >/dev/null 2>&1
```

Use `2>/dev/null` to suppress stderr, `>/dev/null` to suppress stdout. Prefer `$(...)` for command substitution.
