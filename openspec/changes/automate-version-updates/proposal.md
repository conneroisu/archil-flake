# Proposal: Automate Version Updates

## Why

The archil-flake repository packages the Archil distributed storage client for Nix/NixOS users. Currently, updating to new Archil versions requires manual intervention - a developer must run `./update.sh`, test the build, create a commit, and open a PR. This manual process delays adoption of new versions, consumes developer time, and may result in missed updates. Automating this workflow will ensure the package stays current with upstream releases while maintaining quality through automated testing.

## Overview

Implement a GitHub Actions workflow that automatically checks for new Archil client versions on a weekly schedule, runs the existing `update.sh` script, and creates or updates a pull request with the changes. The workflow will include comprehensive testing (builds, flake checks, multi-arch validation, and formatting) and will automatically merge the PR when all checks pass.

## Problem Statement

Currently, updating the Archil client package to new versions requires manual intervention:
1. Developer must manually run `./update.sh` to check for updates
2. Developer must manually create a commit and PR
3. Developer must wait for checks and manually merge

This manual process:
- Delays adoption of new upstream versions
- Requires developer time and attention
- May result in missed updates during periods of low activity
- Creates inconsistency in update timing

## Proposed Solution

Create a scheduled GitHub Action (`update-archil-version.yml`) that:
1. Runs weekly (Mondays at midnight UTC) via cron schedule
2. Executes `./update.sh` to check for and apply version updates
3. Detects if changes were made to `flake.nix`
4. Creates a new PR or updates an existing "chore: update archil" PR
5. Runs comprehensive validation checks:
   - `nix build` on x86_64-linux
   - `nix build` on aarch64-linux (via GitHub hosted runners)
   - `nix flake check` for validation
   - `nix fmt` to verify formatting
6. Auto-merges the PR when all checks pass

## Scope

### In Scope
- GitHub Actions workflow file creation
- Integration with existing `update.sh` script (no modifications needed)
- PR creation and updates using GitHub's native API or CLI
- Multi-architecture build testing
- Automated PR merging with proper checks
- Proper error handling and notification on failure

### Out of Scope
- Modifications to `update.sh` script (works as-is)
- Changes to flake.nix structure
- Custom notification systems beyond GitHub's built-in mechanisms
- Rollback mechanisms (handled by Git/GitHub natively)
- Version pinning or manual override mechanisms (can be added in future)

## Success Criteria

1. **Automation**: Workflow runs weekly without manual intervention
2. **Reliability**: Successfully detects and applies updates when available
3. **Safety**: All checks must pass before auto-merge
4. **Idempotency**: Running with no updates available does nothing (no empty PRs)
5. **Transparency**: Clear PR descriptions showing version changes and test results
6. **Maintainability**: Workflow is well-documented and easy to understand

## Dependencies

- Existing `update.sh` script (must remain functional as-is)
- GitHub Actions runner environment with Nix installed
- GitHub token with PR creation and merge permissions
- Multi-architecture GitHub runners (x86_64-linux, aarch64-linux)

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|-----------|
| Upstream S3 URL changes | High - update.sh fails | Workflow detects and reports failure; manual intervention needed |
| Breaking changes in new version | High - build fails | Automated checks prevent auto-merge; PR remains open for review |
| GitHub API rate limits | Medium - workflow fails | Use built-in GITHUB_TOKEN; schedule during low-traffic times |
| Flake lock conflicts | Low - merge conflicts | PR updates handle rebasing; worst case requires manual resolution |
| False positive on checks | Low - bad version merged | Comprehensive multi-stage checks reduce probability |

## Timeline

Estimated implementation: 1-2 hours
- Workflow creation: 30 min
- Testing and validation: 30-60 min
- Documentation updates: 15-30 min

## Alternatives Considered

1. **Dependabot**: Not suitable for custom update scripts and Nix flakes
2. **Manual cron job**: Less transparent, harder to audit, no PR workflow
3. **Daily updates**: Too frequent; weekly provides good balance
4. **No auto-merge**: Adds manual step; auto-merge with checks is safe
