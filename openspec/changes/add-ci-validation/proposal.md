# Add CI Validation Workflows

## Why

The project currently has automated version updates but lacks comprehensive CI validation for pull requests and commits to main. This creates risk of merging broken builds, formatting issues, or invalid flake configurations. Adding CI validation will catch issues early and maintain code quality.

## What Changes

- Add PR validation workflow that runs on all pull requests
  - Build validation for both x86_64-linux and aarch64-linux architectures
  - Format checking with auto-fix capability
  - Flake structure validation
- Add main branch validation workflow that runs on commits to main
  - Full build validation for both architectures
  - Format and flake checks
- Reuse validation jobs from the existing update-archil-version.yml workflow where possible
- Use GitHub Actions caching for Nix to improve build performance

## Impact

- **Affected specs**: New capability `ci-validation`
- **Affected code**:
  - New workflow file: `.github/workflows/ci.yml`
  - Potentially refactor `.github/workflows/update-archil-version.yml` to use reusable workflows
- **User impact**: PRs will require passing CI checks before merge
- **Performance**: Initial builds may take 5-10 minutes; subsequent builds should be faster with caching
