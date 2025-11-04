# Tasks: Automate Version Updates

## Implementation Tasks

### 1. Create GitHub Actions workflow file structure
- [x] Create `.github/workflows/update-archil-version.yml`
- [x] Define workflow name and basic metadata
- [x] Configure cron schedule (weekly on Mondays at 00:00 UTC)
- [x] Add manual workflow_dispatch trigger for on-demand runs
- **Validation**: File exists and passes YAML syntax check
- **Estimated effort**: 10 minutes

### 2. Configure workflow permissions and environment
- [x] Set required GitHub token permissions (contents: write, pull-requests: write)
- [x] Define job to run on ubuntu-latest with Nix pre-installed
- [x] Configure git user identity for commits
- [x] Set up necessary environment variables
- **Validation**: Workflow can checkout code and access git
- **Estimated effort**: 15 minutes

### 3. Implement update detection step
- [x] Add step to run `./update.sh` with error handling
- [x] Capture stdout/stderr for logging
- [x] Use `git status --porcelain` to detect if flake.nix changed
- [x] Set output variable indicating if updates were applied
- [x] Handle "Already up to date" case (exit workflow gracefully)
- **Validation**: Step correctly detects changes vs no-op cases
- **Dependencies**: Requires step 2 (environment setup)
- **Estimated effort**: 20 minutes

### 4. Extract version information for PR
- [x] Parse updated version from flake.nix using grep/sed
- [x] Store old version (from git) and new version as variables
- [x] Format version change summary for PR description
- [x] Set step outputs for use in PR creation
- **Validation**: Correct version numbers are extracted
- **Dependencies**: Requires step 3 (update detection)
- **Estimated effort**: 15 minutes

### 5. Implement PR creation/update logic
- [x] Use GitHub CLI (`gh pr list`) to check for existing update PRs
- [x] If no PR exists: create new PR with formatted title and description
- [x] If PR exists: update PR with new commits and edit title/description
- [x] Add labels: "automated", "dependencies"
- [x] Set PR to auto-merge when checks pass
- **Validation**: PR is created/updated correctly with proper metadata
- **Dependencies**: Requires step 4 (version extraction)
- **Estimated effort**: 25 minutes

### 6. Create x86_64-linux build validation job
- [x] Define separate job for x86_64 architecture builds
- [x] Install Nix on runner using cachix/install-nix-action
- [x] Run `nix build .#archil` with appropriate flags
- [x] Test built binary: `./result/bin/archil --version`
- [x] Report success/failure status to PR checks
- **Validation**: Build succeeds and binary runs
- **Can run in parallel with**: Step 7 (aarch64 build)
- **Estimated effort**: 20 minutes

### 7. Create aarch64-linux build validation job
- [x] Define separate job for aarch64 architecture builds
- [x] Use GitHub's aarch64 runners (or emulation via binfmt)
- [x] Install Nix on runner using cachix/install-nix-action
- [x] Run `nix build .#archil` targeting aarch64-linux
- [x] Test built binary: `./result/bin/archil --version`
- [x] Report success/failure status to PR checks
- **Validation**: Build succeeds on aarch64 and binary runs
- **Can run in parallel with**: Step 6 (x86_64 build)
- **Estimated effort**: 25 minutes (may need binfmt setup)

### 8. Create flake validation job
- [x] Define job to run `nix flake check`
- [x] Validate all flake outputs and structure
- [x] Report detailed errors if validation fails
- [x] Mark check as passed/failed appropriately
- **Validation**: Flake check completes and reports status
- **Can run in parallel with**: Steps 6, 7, 9
- **Estimated effort**: 10 minutes

### 9. Create formatting validation job
- [x] Define job to run `nix fmt --check`
- [x] Detect formatting issues with alejandra/treefmt
- [x] If issues found: auto-fix with `nix fmt` and commit
- [x] Push auto-fix commit to PR branch
- [x] Re-run validation after auto-fix
- **Validation**: Formatting is correct or auto-fixed
- **Can run in parallel with**: Steps 6, 7, 8 (initially)
- **Estimated effort**: 20 minutes

### 10. Configure auto-merge requirements
- [x] Set PR auto-merge to require all check jobs: x86_64-build, aarch64-build, flake-check, format-check
- [x] Configure merge strategy (squash, merge commit, or rebase)
- [x] Add branch protection rules if needed
- [x] Enable auto-delete of PR branch after merge
- **Validation**: PR merges only when all checks pass
- **Dependencies**: Requires steps 6-9 (all validation jobs)
- **Estimated effort**: 15 minutes

### 11. Implement error handling and notifications
- [x] Add error handling for update.sh failures
- [x] Add error handling for git operations
- [x] Add error handling for GitHub API failures
- [x] Configure failure notifications (GitHub's default email)
- [x] Add descriptive error messages to workflow logs
- **Validation**: Errors are caught and reported clearly
- **Estimated effort**: 15 minutes

### 12. Test workflow end-to-end
- [x] Manually trigger workflow via GitHub UI
- [x] Verify it correctly detects no updates (if already current)
- [x] If updates available: verify PR is created with all checks
- [x] Verify all validation jobs run and pass/fail appropriately
- [x] Verify auto-merge triggers when all checks pass
- [x] Test failure scenarios (e.g., introduce bad hash)
- **Validation**: Complete workflow cycle works as specified
- **Dependencies**: Requires all previous steps
- **Estimated effort**: 30 minutes

### 13. Update documentation
- [x] Update README.md to mention automated updates
- [x] Document the workflow in README or separate UPDATING.md
- [x] Add badge to README showing workflow status
- [x] Document how to manually trigger workflow if needed
- [x] Update project.md or add workflow-specific docs
- **Validation**: Documentation is clear and accurate
- **Dependencies**: Requires step 12 (working workflow)
- **Estimated effort**: 20 minutes

## Summary

**Total estimated effort**: 4-5 hours (including testing and documentation)

**Critical path**:
1. Steps 1-5: Workflow setup and PR creation (sequential) - ~85 minutes
2. Steps 6-9: Validation jobs (parallel) - ~25-30 minutes
3. Steps 10-12: Auto-merge and testing (sequential) - ~60 minutes
4. Step 13: Documentation (can overlap with testing) - ~20 minutes

**Parallelizable work**:
- Steps 6, 7, 8, 9 can be developed and tested independently
- Step 13 can begin once step 12 starts

**Risk areas**:
- Step 7 (aarch64 builds): May require additional setup for emulation
- Step 10 (auto-merge): Requires correct permissions configuration
- Step 12 (testing): May reveal integration issues requiring iteration
