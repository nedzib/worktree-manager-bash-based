# Current Commands — wtm (Worktree Manager)

> Documented from the existing Bun/TypeScript implementation before porting to pure Bash.

---

## Global

- Entry point: `index.ts` → calls `parseArgs(process.argv)` and `runCommand(parsedArgs)`.
- Argument parsing: custom `--flag value`, `--flag`, `-f`, and positional args.
- Error handling: catches all errors, prints `❌ Error: <message>`, exits with code 1.

---

## `wtm init <url> [path]`

Clone a remote repository into a wtm-managed bare structure.

**Flow (InitManager.run):**
1. Determine target directory: `path ?? extractedRepoName(url)`.
2. Fail if directory already exists.
3. `mkdir -p <targetDir>`.
4. `git clone --bare <url> <targetDir>/.git`.
5. Configure fetch refspec: `+refs/heads/*:refs/remotes/origin/*`.
6. `git fetch origin`.
7. Detect default branch via `origin/HEAD` → fallback `main` → fallback `master`.
8. Create initial worktree: `git --git-dir=<targetDir>/.git worktree add <targetDir>/<defaultBranch> origin/<defaultBranch>`.

---

## `wtm init [path]`

Adopt an existing non-bare git repository into wtm structure.

**Flow (InitManager.adopt):**
1. Resolve target directory (default cwd).
2. Validate:
   - `.git/` must exist as directory (not file).
   - `core.bare` must not be `true`.
   - Must have remote `origin`.
   - Working tree must be clean (`git diff --quiet` and `git diff --cached --quiet`).
   - No existing worktrees except the main one (`git worktree list --porcelain` returns 1 block).
   - HEAD must not be detached (`git branch --show-current` returns a branch name).
   - `.wtm-adopt-tmp/` must not exist.
3. Detect default branch (best-effort).
4. **Conversion (with rollback on failure):**
   - Create `.wtm-adopt-tmp/`.
   - Move all non-`.git` entries into temp dir.
   - `git config core.bare true`.
   - Configure fetch refspec.
   - `git fetch origin`.
   - `git worktree add <targetDir>/<currentBranch> <currentBranch>` (preserves local branch).
   - Copy temp files back into worktree (recursive, no-clobber).
   - Remove temp dir.
5. On any failure: rollback `core.bare`, remove worktree, move files back, delete temp dir.

---

## `wtm create <name> --from <base_branch> [--no-shell]`

Create a new worktree from a base branch.

**Flow (WorktreeManager.createWorktree):**
1. `ensureBareRepo()` — `git config --get core.bare` must return `true`.
2. `fetchBranch(baseBranch)`:
   - `git ls-remote origin <branch>` to get remote commit hash.
   - `git update-ref -d refs/remotes/origin/<branch>` to clear stale ref.
   - `git fetch origin +<branch>:refs/remotes/origin/<branch>`.
   - Verify local tracking ref matches remote hash.
3. `git worktree add -b <name> <cwd>/<name> origin/<baseBranch>`.
4. Set up remote tracking in worktree:
   - `git config branch.<name>.remote origin`
   - `git config branch.<name>.merge refs/heads/<name>`
   - `git fetch origin <name>:refs/remotes/origin/<name>`
5. Execute `post_create` hook if `.wtm/post_create` exists in worktree.
6. Unless `--no-shell`, spawn `$SHELL` (fallback `/bin/bash`) in worktree directory with inherited stdin/stdout/stderr.

---

## `wtm checkout <name>`

Create worktree from an existing remote branch.

**Flow (WorktreeManager.checkoutWorktree):**
1. `ensureBareRepo()`.
2. List worktrees — if one already matches by path or branch name, print info and exit.
3. `git ls-remote --heads origin <name>` — verify remote branch exists.
4. `fetchBranch(name)`.
5. Check if local branch exists (`git show-ref --verify refs/heads/<name>`).
   - If yes: `git worktree add <cwd>/<name> <name>`.
   - If no: `git worktree add -b <name> <cwd>/<name> origin/<name>`.
6. Set up remote tracking in worktree.
7. Execute `post_create` hook.

---

## `wtm list`

List all worktrees in the current bare repo.

**Flow (WorktreeManager.listWorktrees):**
1. `ensureBareRepo()`.
2. `git worktree list --porcelain`.
3. Parse blocks (separated by blank lines), extract:
   - `worktree <path>`
   - `HEAD <commit>`
   - `branch refs/heads/<name>`
   - `bare` flag
4. Print table: `name (30)` | `status (20)` | `commit (9)`.

---

## `wtm delete <name> [--force]`

Delete a worktree.

**Flow (WorktreeManager.deleteWorktree):**
1. `ensureBareRepo()`.
2. Find worktree by suffix path or branch name.
3. Reject if not found or if it's the bare repo.
4. `git worktree remove <path> [--force]`.

---

## `wtm cleanup [--base <branch>] [--dry-run] [--yes]`

Find and delete merged worktrees interactively (or automatically).

**Flow (CleanupManager.run):**
1. `ensureBareRepo()`.
2. Determine base branch: `--base` flag → auto-detect via `origin/HEAD` → `main` → `master`.
3. `git fetch origin <baseBranch>`.
4. For each non-bare, non-protected (`main`, `master`, `next`, `prerelease`) worktree:
   - Check `isMerged`: remote branch deleted OR commit is ancestor of `origin/<baseBranch>` (`git merge-base --is-ancestor`).
   - Check `hasUncommittedChanges`: unstaged, staged, or untracked files.
   - Check `hasUnpushedCommits`: `git log origin/<baseBranch>..HEAD --oneline` non-empty.
   - Only keep as candidate if merged AND clean AND no unpushed commits.
5. If `--dry-run`: print candidates and exit.
6. If `--yes`: delete all candidates.
7. Otherwise: interactive multi-select with `@inquirer/prompts` checkbox, then confirm.
8. Delete selected worktrees via `WorktreeManager.deleteWorktree(name, true)` (force).
9. `git worktree prune`.

---

## Hooks

**post_create:**
- Triggered after `create` and `checkout`.
- Looks for `<worktreePath>/.wtm/post_create`.
- If file exists and is executable (or we run it via `bash <file>`), execute it with env vars:
  - `WORKTREE_DIR`
  - `WORKTREE_NAME`
  - `BASE_BRANCH`
  - `BARE_REPO_PATH`
- Executed in worktree directory.

---

## Internal Helpers

- `extractRepoName(url)` — handles `git@host:org/repo.git`, `https://host/org/repo.git`, `ssh://git@host/org/repo.git`. Returns last segment without `.git`.
- `detectDefaultBranch(gitDir)` — uses `origin/HEAD`, falls back to `main`, then `master`.
- `isExistingRepo(path)` — checks if directory exists and contains `.git`.

---

## Files Mapping (TypeScript → Bash)

| TS File          | Responsibility                                 |
|------------------|------------------------------------------------|
| `index.ts`       | Entry point, parse args, route                 |
| `src/cli.ts`     | Arg parsing, help text, command dispatch       |
| `src/init.ts`    | Clone (`init url`) and adopt (`init [path]`)   |
| `src/worktree.ts`| create, checkout, list, delete                 |
| `src/cleanup.ts` | cleanup with merge detection + interactive UI  |
| `src/hooks.ts`   | post_create hook execution                     |
