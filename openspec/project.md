# Project Context

## Purpose
Unofficial reproducible Nix package/flake for the [Archil](https://archil.com) distributed storage client. This project packages the official Archil client binary for use with Nix and NixOS, providing:
- Reproducible builds with locked dependencies
- Multi-architecture support (x86_64-linux, aarch64-linux)
- Declarative configuration for NixOS
- Automatic dependency management via autoPatchelfHook

## Tech Stack
- **Nix/NixOS**: Primary packaging system with flakes enabled (Nix 2.4+)
- **Bash**: Shell scripting for automation (update.sh)
- **RPM Package Management**: Extracting binaries from upstream RPM packages
- **Build Tools**:
  - autoPatchelfHook for automatic dependency patching
  - rpm2cpio for RPM extraction
  - makeWrapper for binary wrapping
- **Formatters/Linters**:
  - alejandra (Nix formatter)
  - nixd (Nix language server)
  - statix (Nix linter)
  - deadnix (Dead code detection for Nix)
  - gofmt, golines, goimports (Go formatters, for any Go code)
  - treefmt-nix (unified formatting)

## Project Conventions

### Code Style
- **Nix**: Use alejandra formatting style (enforced via treefmt)
- **Bash Scripts**:
  - Always use `set -euo pipefail` at script start
  - Use proper error handling and logging functions
  - Support `--dry-run` and `--verbose` flags for maintainability
  - Color-coded output (RED, GREEN, YELLOW, BLUE, NC)
  - All log output to stderr to not interfere with command substitution
- **Naming**: Use descriptive script names and clear function names
- **Comments**: Prefer self-documenting code; use comments for complex logic only

### Architecture Patterns
- **Binary Packaging**: Fetch upstream RPM packages from S3, extract and repackage for Nix
- **Multi-Architecture Support**: Conditional logic based on `pkgs.stdenv.hostPlatform.isAarch64`
- **Dependency Management**: Use autoPatchelfHook to automatically resolve binary dependencies
- **Flake Structure**:
  - `packages.default` and `packages.archil` for the main package
  - `devShells.default` with development tools
  - `formatter` using treefmt-nix
  - Utility scripts in `scripts` attribute set
- **Version Management**: Automated update script that:
  - Fetches latest version from upstream install script
  - Verifies package availability on S3
  - Computes SHA256 hashes using nix-prefetch-url
  - Updates flake.nix automatically

### Testing Strategy
- **Build Testing**: Use `nix build` and `nix flake check` to verify package builds
- **Runtime Testing**: Test with `./result/bin/archil --version` after building
- **Pre-deployment**: Always test both x86_64 and aarch64 builds when updating
- **Verification**: The update.sh script includes package verification before updating

### Git Workflow
- **Main Branch**: `main` is the primary development and deployment branch
- **Commit Format**: Descriptive commit messages (e.g., "Update archil to X.Y.Z-TIMESTAMP")
- **Update Process**:
  1. Run `./update.sh` to check for new versions
  2. Test build with `nix build`
  3. Commit changes with version info
  4. Push to trigger any CI/CD
- **Branch Strategy**: Direct commits to main for version updates; feature branches for structural changes

## Domain Context

### FUSE Filesystems
- Archil uses FUSE (Filesystem in Userspace) to mount cloud storage as local filesystems
- Requires FUSE2 (version 2.x) libraries and kernel modules
- Root/sudo privileges required for mounting operations

### Distributed Storage
- Archil is a distributed storage service with regional endpoints (e.g., aws-us-east-1)
- Supports disk checkout/checkin for offline use
- Handles authentication via email/password, API keys, or OAuth

### NixOS Packaging
- Proprietary binary packaging requires:
  - `allowUnfree = true` in Nix configuration
  - Proper library path wrapping for runtime dependencies
  - autoPatchelfHook for ELF binary patching
- Flakes provide reproducibility through `flake.lock`

## Important Constraints

### Technical Constraints
- **Unfree License**: Archil client is proprietary software by Archil, Inc.
- **Binary-Only**: No source code available; must package pre-built binaries
- **Architecture Support**: Limited to x86_64-linux and aarch64-linux
- **Upstream Dependency**: Relies on Archil's S3 bucket for package availability
- **Library Dependencies**: Must bundle/wrap FUSE2, OpenSSL, libcap for runtime

### Build Constraints
- **Nix Version**: Requires Nix 2.4+ with flakes enabled
- **Hash Stability**: SHA256 hashes must be computed and locked for reproducibility
- **Version Format**: Upstream uses `MAJOR.MINOR.PATCH-TIMESTAMP` format

### User Environment
- **Kernel Requirements**: Linux kernel 5.1+ for FUSE support
- **Permissions**: Requires root/sudo for mount operations or fuse group membership

## External Dependencies

### Upstream Services
- **Archil S3 Bucket**: `https://s3.amazonaws.com/archil-client/`
  - Install script: `s3.amazonaws.com/archil-client/install`
  - RPM packages: `s3.amazonaws.com/archil-client/pkg/archil-VERSION.ARCH.rpm`
- **Archil Console**: `https://console.archil.com` (user authentication and disk management)
- **Archil Documentation**: `https://docs.archil.com` (official documentation)

### Nix Dependencies
- **nixpkgs**: `github:NixOS/nixpkgs/nixpkgs-unstable`
- **flake-utils**: `github:numtide/flake-utils` (multi-system flake utilities)
- **treefmt-nix**: `github:numtide/treefmt-nix` (unified formatting)

### Runtime Libraries (auto-managed)
- libfuse2 (FUSE version 2.x)
- OpenSSL (cryptography)
- libcap (Linux capabilities)
- stdenv.cc.cc.lib (C++ standard library)
