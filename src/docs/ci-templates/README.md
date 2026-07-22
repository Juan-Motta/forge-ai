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
   - Enable **"Require branches to be up to date before merging"** (strict status checks), or
     use a merge queue. Without this, GitHub allows merging after the base branch has advanced,
     so the merge-result commit that `gates` tested can differ from what actually lands — the
     "exact code being merged" assurance in `gates.yml`'s checkout comment only holds once this
     is on (or a merge queue is used).
   - Enable **"Do not allow bypassing the above settings"** and **disallow direct pushes** to the
     protected branch, so UI merges / `gh pr merge` / Dependabot cannot skip the check.
4. Add a **CODEOWNERS** rule requiring review on the workflow file itself, and turn on **"Require
   review from Code Owners"** in branch protection. Without this, a PR can edit
   `.github/workflows/gates.yml` (weaken the test step, or remove/rename the job) in the same PR
   it's supposed to gate, and GitHub runs that PR's own version of the workflow — so the gate
   can neuter itself while keeping its required-check name green. Example `CODEOWNERS`:
   ```
   /.github/workflows/  @your-org/maintainers
   /CODEOWNERS          @your-org/maintainers
   ```

## Honesty

Until the test command is filled, the check is required, **and** bypass is disabled, this is not
yet the Verified tier. Even then, the tier only binds against a bad-faith or mistaken actor when
**all** of the following hold: the workflow file is CODEOWNERS-protected (step 4), "Require
branches to be up to date before merging" is enabled or a merge queue is used (step 3), and
"Do not allow bypassing the above settings" includes admins. Repo/org **admins** (and some
GitHub Apps) can still bypass branch protection unless you've configured otherwise — decide who
that should be.
