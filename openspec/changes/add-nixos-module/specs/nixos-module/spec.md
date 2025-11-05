# NixOS Module Specification

## ADDED Requirements

### Requirement: Module Structure
The NixOS module SHALL provide a declarative interface for configuring Archil mounts and authentication through the NixOS configuration system.

#### Scenario: Module is available in flake outputs
- **WHEN** a user imports the flake
- **THEN** `nixosModules.default` is available for import into their NixOS configuration

#### Scenario: Module can be imported
- **WHEN** a user adds `inputs.archil-flake.nixosModules.default` to their NixOS modules
- **THEN** the `services.archil` configuration namespace becomes available

### Requirement: Service Enable Option
The module SHALL provide a top-level enable option to control whether Archil services are active.

#### Scenario: Service can be enabled
- **WHEN** `services.archil.enable = true;` is set
- **THEN** all configured Archil mounts are activated via systemd services

#### Scenario: Service can be disabled
- **WHEN** `services.archil.enable = false;` is set
- **THEN** no Archil systemd services are created or started

### Requirement: Package Override Option
The module SHALL allow users to override the default Archil package.

#### Scenario: Default package is used
- **WHEN** `services.archil.package` is not specified
- **THEN** the module uses the default Archil package from the flake

#### Scenario: Custom package is used
- **WHEN** `services.archil.package = pkgs.archil-custom;` is set
- **THEN** the custom package is used for all mount operations

### Requirement: Declarative Mount Configuration
The module SHALL support declarative configuration of Archil mounts through an attribute set.

#### Scenario: Multiple mounts can be configured
- **WHEN** multiple mounts are defined under `services.archil.mounts`
- **THEN** each mount gets its own systemd service

#### Scenario: Mount requires disk name
- **WHEN** a mount is configured
- **THEN** it MUST specify a `diskName` attribute

#### Scenario: Mount requires mount point
- **WHEN** a mount is configured
- **THEN** it MUST specify a `mountPoint` attribute (absolute path)

#### Scenario: Mount requires region
- **WHEN** a mount is configured
- **THEN** it MUST specify a `region` attribute (e.g., "aws-us-east-1")

### Requirement: IAM Role Authentication
The module SHALL support IAM role-based authentication for EC2 instances.

#### Scenario: IAM authentication is default
- **WHEN** `authMethod` is set to "iam" or not specified
- **THEN** the mount command does not include `--auth-token` flag

#### Scenario: IAM authentication works on EC2
- **WHEN** running on an EC2 instance with appropriate IAM role
- **THEN** the mount succeeds without explicit credentials

### Requirement: Token-Based Authentication
The module SHALL support token-based authentication for non-AWS or cross-region scenarios.

#### Scenario: Token authentication can be configured
- **WHEN** `authMethod = "token";` is set
- **THEN** the module expects an `authToken` attribute

#### Scenario: Token is passed securely
- **WHEN** `authToken` is provided
- **THEN** the systemd service uses `--auth-token` flag with the token value

#### Scenario: Token can reference secrets
- **WHEN** `authTokenFile` is provided instead of `authToken`
- **THEN** the systemd service reads the token from the specified file at runtime

### Requirement: Systemd Service Generation
The module SHALL generate systemd mount services for each configured mount.

#### Scenario: Service naming convention
- **WHEN** a mount named "data-disk" is configured
- **THEN** a systemd service `archil-mount-data-disk.service` is created

#### Scenario: Service dependencies
- **WHEN** a systemd mount service is created
- **THEN** it depends on `network-online.target` and requires FUSE kernel module

#### Scenario: Service restart behavior
- **WHEN** an Archil mount service fails
- **THEN** systemd automatically restarts it with exponential backoff

#### Scenario: Service executes mount command
- **WHEN** the systemd service starts
- **THEN** it executes `archil mount <diskName> <mountPoint> --region <region>` with appropriate auth flags

#### Scenario: Mount point is created automatically
- **WHEN** a mount point directory does not exist
- **THEN** the systemd service creates it before mounting

### Requirement: FUSE Dependency Management
The module SHALL ensure FUSE kernel module and user permissions are configured.

#### Scenario: FUSE module is loaded
- **WHEN** Archil services are enabled
- **THEN** the FUSE kernel module is loaded automatically

#### Scenario: User can access FUSE
- **WHEN** a non-root user needs to mount Archil disks
- **THEN** the module ensures proper permissions are configured

### Requirement: Unmount on Service Stop
The module SHALL cleanly unmount Archil filesystems when services are stopped.

#### Scenario: Unmount command is executed
- **WHEN** a systemd mount service is stopped
- **THEN** it executes `archil unmount <mountPoint>` or equivalent umount command

#### Scenario: Graceful shutdown on system halt
- **WHEN** the system is shutting down
- **THEN** all Archil mounts are unmounted before the shutdown proceeds

### Requirement: Configuration Validation
The module SHALL validate configuration options and provide clear error messages.

#### Scenario: Missing required fields are detected
- **WHEN** a mount is configured without `diskName`, `mountPoint`, or `region`
- **THEN** NixOS evaluation fails with a descriptive error message

#### Scenario: Invalid mount point paths are rejected
- **WHEN** a relative path is provided for `mountPoint`
- **THEN** NixOS evaluation fails indicating an absolute path is required

#### Scenario: Token auth requires token
- **WHEN** `authMethod = "token";` but neither `authToken` nor `authTokenFile` is provided
- **THEN** NixOS evaluation fails with an error about missing authentication credentials
