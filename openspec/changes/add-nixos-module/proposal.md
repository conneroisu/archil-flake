# Proposal: Add NixOS Service Module

## Why

The current Archil flake only provides the binary package, requiring users to manually configure mounts, authentication, and systemd services. A declarative NixOS module would enable users to configure Archil mounts, authentication credentials, and service management entirely through their NixOS configuration, improving usability and maintainability.

## What Changes

- Add a NixOS module (`nixosModules.default`) to the flake outputs
- Provide declarative configuration options for:
  - Archil package installation
  - Mount point definitions with region and authentication settings
  - Credential management (IAM role or token-based authentication)
  - Systemd service generation for each mount
  - Automatic dependency management (FUSE kernel module, permissions)
- Module options will support:
  - `services.archil.enable` - Enable the Archil service
  - `services.archil.package` - Override the Archil package
  - `services.archil.mounts.<name>` - Declarative mount configurations
  - Each mount will have: `diskName`, `mountPoint`, `region`, `authMethod`, `authToken`
  - Automatic systemd service generation with proper ordering and dependencies

## Impact

- **Affected specs**: Creates new `nixos-module` capability
- **Affected code**:
  - `flake.nix` - Add `nixosModules.default` output
  - New file: `modules/archil.nix` - NixOS module implementation
- **User experience**: Enables declarative configuration instead of manual setup
- **Backwards compatibility**: No breaking changes; existing package usage remains unchanged
