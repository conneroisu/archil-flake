# CI Validation Specification

## ADDED Requirements

### Requirement: Pull Request Validation

The system SHALL validate all pull requests with comprehensive CI checks before allowing merge.

#### Scenario: PR triggers validation

- **WHEN** a pull request is opened or updated
- **THEN** the CI validation workflow runs automatically
- **AND** all validation jobs must pass before merge is allowed

#### Scenario: PR modifies Nix files

- **WHEN** a pull request modifies flake.nix or other Nix files
- **THEN** build validation runs for both x86_64-linux and aarch64-linux
- **AND** flake validation checks the flake structure
- **AND** format checking verifies code style

#### Scenario: PR with formatting issues

- **WHEN** a pull request has formatting issues
- **THEN** the format check job detects the issues
- **AND** the job automatically applies formatting fixes
- **AND** the fixes are committed to the PR branch
- **AND** subsequent checks pass

### Requirement: Multi-Architecture Build Validation

The system SHALL validate package builds on both supported architectures for every change.

#### Scenario: x86_64-linux build validation

- **WHEN** CI runs build validation
- **THEN** the package builds successfully on x86_64-linux
- **AND** the binary is tested with `archil --version`
- **AND** build logs are captured for debugging

#### Scenario: aarch64-linux build validation

- **WHEN** CI runs build validation
- **THEN** the package builds successfully on aarch64-linux using QEMU emulation
- **AND** the binary architecture is verified with `file` command
- **AND** build logs are captured for debugging

#### Scenario: Build failure on any architecture

- **WHEN** the build fails on any supported architecture
- **THEN** the CI job fails with clear error messages
- **AND** build logs are available for debugging
- **AND** the PR cannot be merged until fixed

### Requirement: Flake Structure Validation

The system SHALL validate the Nix flake structure and configuration on every change.

#### Scenario: Flake check validation

- **WHEN** CI runs flake validation
- **THEN** `nix flake check` executes successfully
- **AND** all flake outputs are valid
- **AND** any flake errors are reported clearly

#### Scenario: Flake metadata validation

- **WHEN** CI runs flake validation
- **THEN** the flake inputs are properly locked
- **AND** the flake description and metadata are present
- **AND** the flake follows nixpkgs conventions

### Requirement: Format Validation

The system SHALL enforce consistent code formatting using the project's treefmt configuration.

#### Scenario: Format check execution

- **WHEN** CI runs format validation
- **THEN** `nix fmt -- --check .` verifies all files
- **AND** any formatting issues are detected
- **AND** the job reports which files need formatting

#### Scenario: Auto-fix formatting on PR

- **WHEN** format check detects issues on a PR
- **THEN** `nix fmt` automatically fixes the formatting
- **AND** the fixes are committed with message "style: auto-fix formatting"
- **AND** the commit is pushed to the PR branch
- **AND** subsequent format checks pass

#### Scenario: Format validation after auto-fix

- **WHEN** auto-fix formatting commits changes
- **THEN** a verification step runs `nix fmt -- --check .` again
- **AND** confirms all formatting is now correct
- **AND** the job passes

### Requirement: Main Branch Continuous Validation

The system SHALL validate every commit to the main branch to ensure stability.

#### Scenario: Main branch commit triggers CI

- **WHEN** code is pushed to the main branch
- **THEN** the CI validation workflow runs
- **AND** all validation checks execute
- **AND** build status is reported

#### Scenario: Main branch build failure

- **WHEN** a build fails on the main branch
- **THEN** the CI job fails and reports the error
- **AND** notifications alert maintainers
- **AND** the commit is identified as breaking

### Requirement: Nix Build Caching

The system SHALL use caching to improve CI build performance and reduce resource usage.

#### Scenario: Cache Nix store between runs

- **WHEN** CI runs build validation
- **THEN** the Nix store is cached between runs
- **AND** subsequent builds reuse cached derivations
- **AND** build time is reduced significantly for unchanged dependencies

#### Scenario: Cache invalidation on flake changes

- **WHEN** flake.nix or flake.lock changes
- **THEN** the cache is invalidated appropriately
- **AND** new dependencies are fetched and cached
- **AND** subsequent runs use the new cache

### Requirement: GitHub Actions Configuration

The system SHALL use GitHub Actions for all CI workflows with appropriate permissions and triggers.

#### Scenario: Workflow permissions

- **WHEN** CI workflows execute
- **THEN** they have minimal required permissions
- **AND** read access to repository contents
- **AND** write access to PR comments for status updates (if needed)
- **AND** no elevated privileges unless explicitly required

#### Scenario: Workflow triggers

- **WHEN** configuring CI workflows
- **THEN** PR workflow triggers on pull_request events (opened, synchronize, reopened)
- **AND** main workflow triggers on push to main branch
- **AND** workflows can be manually triggered with workflow_dispatch

#### Scenario: Concurrent workflow runs

- **WHEN** multiple commits are pushed rapidly
- **THEN** concurrent runs for the same PR are cancelled
- **AND** only the latest run continues
- **AND** resources are conserved

### Requirement: Error Reporting and Debugging

The system SHALL provide clear error messages and debugging information when CI checks fail.

#### Scenario: Build failure reporting

- **WHEN** a build fails
- **THEN** the error message is clearly visible in the job summary
- **AND** full build logs are available for download
- **AND** the specific architecture and step that failed is identified

#### Scenario: Format check failure reporting

- **WHEN** format check fails
- **THEN** the list of incorrectly formatted files is shown
- **AND** developers can see which files need formatting
- **AND** the auto-fix attempt (if any) is logged

#### Scenario: Flake check failure reporting

- **WHEN** flake check fails
- **THEN** the specific flake validation error is shown
- **AND** the failing output or check is identified
- **AND** debugging steps are suggested in the error message
