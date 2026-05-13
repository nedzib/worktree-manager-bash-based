# AGENTS.md

## What this repo is

A single portable Bash script (`wtm`) that wraps `git worktree` to manage bare repositories. Zero build step, zero runtime dependencies beyond Bash and Git. The entire product is one file.

## Edit and verify

```bash
./wtm help          # Syntax check / quick sanity
./wtm --version     # Check version string
```

There is **no test suite**. Manual verification is the only option. If you need to test real git operations, create a disposable bare repo or temp directory.

## Architecture rules

- **Keep it one file.** Do not split `wtm` into modules. All commands and helpers live in the same script.
- **Plain `git` commands only.** No libraries, no wrappers. Redirect output with `>/dev/null 2>&1` or `2>/dev/null` as needed.
- **`set -euo pipefail`** at the top — handle errors explicitly or let them abort.

## Key implementation details easy to miss

### Worktree context detection (`create`, `checkout`)

Both commands detect whether they are run from the bare repo root or from inside an existing worktree. They compare `git rev-parse --git-dir` vs `git rev-parse --git-common-dir`:

- Equal + `core.bare == true` → in bare repo root → `bare_path = $(pwd)`
- Different + `core.bare != true` → inside a worktree → `bare_path = $(dirname git-common-dir)`

This prevents creating nested worktrees (e.g. `main/feature-auth` instead of `feature-auth`).

### Adopt rollback (`wtm_cmd_init_adopt`)

The adopt flow (converting an existing non-bare repo) uses `trap rollback ERR`. If any step fails after filesystem changes began, it reverts:
- Removes created worktree (`git worktree remove --force` + `rm -rf`)
- Resets `core.bare` to `false`
- Moves files back from `.wtm-adopt-tmp/`
- Cleans up temp dir

### Fetch with corruption guard (`wtm_fetch_branch`)

Before fetching a branch, it explicitly deletes the local tracking ref:

```bash
git update-ref -d "refs/remotes/origin/$branch"
git fetch origin "+${branch}:refs/remotes/origin/${branch}"
```

Then verifies the local hash matches the remote hash. This handles stale/corrupted refs.

### Hooks

`wtm_run_hook` looks for `<worktree>/.wtm/post_create` and runs it with env vars:
- `WORKTREE_DIR`, `WORKTREE_NAME`, `BASE_BRANCH`, `BARE_REPO_PATH`

Hooks are per-worktree (committed to the branch), not per-repo.

## What to leave alone

- `install.sh` — simple copy-to-`~/.local/bin` installer. No fancy logic needed.
- `CLAUDE.md` — parallel instructions for Claude Code. Keep it in sync with `AGENTS.md` if you change architecture.
