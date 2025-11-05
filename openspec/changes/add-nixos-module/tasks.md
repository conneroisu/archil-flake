# Implementation Tasks

## 1. Module Structure
- [ ] 1.1 Create `modules/archil.nix` file with module skeleton
- [ ] 1.2 Define module options using `lib.mkOption` with proper types
- [ ] 1.3 Add module to flake.nix `nixosModules.default` output
- [ ] 1.4 Test that module can be imported in a NixOS configuration

## 2. Configuration Options
- [ ] 2.1 Implement `services.archil.enable` boolean option (default: false)
- [ ] 2.2 Implement `services.archil.package` package option (default: packages.archil)
- [ ] 2.3 Implement `services.archil.mounts` attribute set with submodule
- [ ] 2.4 Define mount submodule options: `diskName`, `mountPoint`, `region`, `authMethod`, `authToken`, `authTokenFile`
- [ ] 2.5 Add proper type definitions and descriptions for all options
- [ ] 2.6 Set reasonable defaults (authMethod = "iam", etc.)

## 3. Configuration Validation
- [ ] 3.1 Add assertions for required fields (diskName, mountPoint, region)
- [ ] 3.2 Validate mountPoint is an absolute path
- [ ] 3.3 Validate authMethod is either "iam" or "token"
- [ ] 3.4 Assert token auth requires authToken or authTokenFile
- [ ] 3.5 Add warnings for common misconfigurations
- [ ] 3.6 Test validation with invalid configurations

## 4. Systemd Service Generation
- [ ] 4.1 Generate one systemd service per configured mount
- [ ] 4.2 Implement service naming convention: `archil-mount-<name>.service`
- [ ] 4.3 Add service dependencies: `network-online.target`, `fuse` kernel module
- [ ] 4.4 Configure service restart policy with exponential backoff
- [ ] 4.5 Set appropriate service type and environment
- [ ] 4.6 Ensure services are enabled when `services.archil.enable = true`

## 5. Mount Command Construction
- [ ] 5.1 Build base mount command: `archil mount <diskName> <mountPoint> --region <region>`
- [ ] 5.2 Add `--auth-token` flag when authMethod is "token"
- [ ] 5.3 Handle authToken value from direct string or authTokenFile
- [ ] 5.4 Use systemd's `LoadCredential` for secure token file handling
- [ ] 5.5 Create mount point directory in ExecStartPre if it doesn't exist
- [ ] 5.6 Test mount command generation for both auth methods

## 6. Unmount Handling
- [ ] 6.1 Implement ExecStop with `archil unmount <mountPoint>` command
- [ ] 6.2 Add fallback to `umount <mountPoint>` if archil unmount fails
- [ ] 6.3 Configure proper timeout for unmount operations
- [ ] 6.4 Test clean shutdown and unmount behavior

## 7. FUSE Dependencies
- [ ] 7.1 Add FUSE kernel module to boot.kernelModules
- [ ] 7.2 Ensure fuse package is available in system packages
- [ ] 7.3 Configure user permissions for FUSE access if needed
- [ ] 7.4 Test that FUSE module loads before Archil services start

## 8. Documentation
- [ ] 8.1 Add module options documentation with descriptions and examples
- [ ] 8.2 Create example configuration in README.md or separate example file
- [ ] 8.3 Document IAM role setup requirements for AWS EC2 usage
- [ ] 8.4 Document token generation and secure storage best practices
- [ ] 8.5 Add troubleshooting section for common issues

## 9. Testing
- [ ] 9.1 Create NixOS VM test with simple mount configuration
- [ ] 9.2 Test IAM authentication method (mount command without token)
- [ ] 9.3 Test token authentication with authToken string
- [ ] 9.4 Test token authentication with authTokenFile
- [ ] 9.5 Test multiple mounts configuration
- [ ] 9.6 Test service restart and failure recovery
- [ ] 9.7 Test clean unmount on service stop
- [ ] 9.8 Verify validation catches configuration errors
- [ ] 9.9 Run `nix flake check` to ensure module passes checks

## 10. Integration
- [ ] 10.1 Test flake can be used with `nix build`
- [ ] 10.2 Test NixOS module can be imported via flake input
- [ ] 10.3 Verify backwards compatibility (package still works standalone)
- [ ] 10.4 Update CHANGELOG.md with new feature
- [ ] 10.5 Run formatter (alejandra) on all Nix files
