# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- NixOS module for declarative Archil mount configuration (`modules/archil.nix:1`)
  - `services.archil.enable` - Enable the Archil service
  - `services.archil.package` - Override the Archil package
  - `services.archil.mounts.<name>` - Declarative mount configurations
  - Support for both IAM and token-based authentication
  - Automatic systemd service generation with proper dependencies
  - FUSE kernel module auto-loading
  - Secure credential handling via systemd's LoadCredential
  - Comprehensive validation with helpful error messages
- NixOS module exposed as `nixosModules.default` in flake outputs (`flake.nix:30`)
- Overlay for archil package (`flake.nix:33`)
- Example configuration file (`example-configuration.nix:1`)
- Automated tests for module functionality (`test.nix:1`)

### Changed

- Flake structure now exports `nixosModules` and `overlays` alongside existing `packages`

## [0.6.4-1760484228] - Initial Release

### Added

- Initial Nix package for Archil client binary
- Support for x86_64-linux and aarch64-linux architectures
- Development shell with Nix tooling
- Auto-patching for dynamic dependencies
