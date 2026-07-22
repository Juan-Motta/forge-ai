# codeforge Verified-tier CI template

`gates.yml` is codeforge's **Verified tier**: the only enforcement that binds for every clone and
every merge (local git hooks are per-clone and skip server-side merges; see
`shared/rules/ship-gates.md`). It reruns your project's tests on the PR **merge result**, outside
any agent's turn.

## Activate

1. Copy the workflow into place:
   ```bash
   cp docs/ci-templates/gates.yml .github/workflows/gates.yml
   ```
2. Edit the **Recompute** step — replace the placeholder with your real test command
   (`npm test`, `uv run pytest`, `go test ./...`, …). The placeholder `exit 1` is intentional so
   an un-configured check can never pass green.
3. In your repo settings, protect the base branch and make **`gates`** a **required status check**:
   - Enable **"Require status checks to pass before merging"** and select `gates`.
   - Enable **"Do not allow bypassing the above settings"** and **disallow direct pushes** to the
     protected branch, so UI merges / `gh pr merge` / Dependabot cannot skip the check.

## Honesty

Until the test command is filled, the check is required, **and** bypass is disabled, this is not
yet the Verified tier. Even then, repo/org **admins** (and some GitHub Apps) can bypass branch
protection unless you configure otherwise — decide who that should be.
