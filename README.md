# Archil Storage Client - Nix Flake

Unofficial reproducible Nix package for the [Archil](https://archil.com) distributed storage client.

## What is Archil?

[Archil](https://docs.archil.com/getting-started/introduction) is a distributed storage service that allows you to mount cloud storage as a local filesystem using FUSE.

This flake packages the official Archil client binary for use with Nix and NixOS.

## Features

- ✅ Multi-architecture support (x86_64-linux, aarch64-linux)
- ✅ Automatic dependency management via autoPatchelfHook
- ✅ Reproducible builds with locked dependencies
- ✅ Declarative NixOS module for mount configuration
- ✅ Support for both IAM and token-based authentication
- ✅ Automatic systemd service generation with proper dependencies

## Installation

### Option 1: Nix Flake (Recommended for Nix Users)

#### Quick Start

Build and run directly:

```bash
# Build the package
nix build github:conneroisu/archil-flake#archil

# Run the client
./result/bin/archil --version
```

#### Add to NixOS Configuration

##### Option A: Using the NixOS Module (Recommended)

Add declarative mount configuration to your `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    archil-flake.url = "github:conneroisu/archil-flake";
  };

  outputs = { nixpkgs, archil-flake, ... }: {
    nixosConfigurations.your-host = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        # Import the Archil NixOS module
        archil-flake.nixosModules.default

        # Add the overlay to get the archil package
        { nixpkgs.overlays = [ archil-flake.overlays.default ]; }

        # Your configuration
        {
          services.archil = {
            enable = true;

            mounts = {
              # Example: IAM-authenticated mount (for AWS EC2 instances)
              data-disk = {
                diskName = "production-data";
                mountPoint = "/mnt/data";
                region = "us-east-1";
                authMethod = "iam";
              };

              # Example: Token-authenticated mount using a file
              backup-disk = {
                diskName = "backup-storage";
                mountPoint = "/mnt/backup";
                region = "us-west-2";
                authMethod = "token";
                authTokenFile = "/run/secrets/archil-token";
              };
            };
          };
        }
      ];
    };
  };
}
```

The module automatically:
- Loads the FUSE kernel module
- Creates systemd services for each mount (e.g., `archil-mount-data-disk.service`)
- Creates mount point directories if they don't exist
- Configures automatic restart on failure with exponential backoff
- Handles graceful unmount on service stop

See `example-configuration.nix` for more examples.

##### Option B: Manual Package Installation

Just install the package without declarative mounts:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    archil-flake.url = "github:conneroisu/archil-flake";
  };

  outputs = { nixpkgs, archil-flake, ... }: {
    nixosConfigurations.your-host = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        {
          environment.systemPackages = [
            archil-flake.packages.x86_64-linux.archil
          ];
        }
      ];
    };
  };
}
```

#### Add to Home Manager

```nix
{
  inputs.archil.url = "github:conneroisu/archil-flake";

  # In your home-manager configuration:
  home.packages = [
    inputs.archil.packages.${pkgs.system}.archil
  ];
}
```

#### Development Shell

```bash
# Enter a shell with archil available
nix shell github:conneroisu/archil-flake#archil

# Or use nix develop if you've cloned the repo
nix develop
archil --version
```

### Option 2: Traditional Installation (For Non-Nix Linux)

If you're not using Nix, install via the official method:

```bash
curl https://s3.amazonaws.com/archil-client/install | sh
```

**Requirements:**
- Linux kernel 5.1 or greater
- libfuse2 installed (`apt install fuse` on Debian/Ubuntu)

## NixOS Module Configuration

The NixOS module provides declarative configuration for Archil mounts. Here are the available options:

### Module Options

- `services.archil.enable` - Enable the Archil service (boolean)
- `services.archil.package` - Override the Archil package (package, default: `pkgs.archil`)
- `services.archil.mounts.<name>` - Attribute set of mount configurations

### Mount Configuration Options

Each mount in `services.archil.mounts.<name>` supports:

- `diskName` - Name of the Archil disk to mount (string, required)
- `mountPoint` - Absolute path where the disk should be mounted (string, required)
- `region` - Archil region where the disk is located (string, required)
- `authMethod` - Authentication method: `"iam"` or `"token"` (default: `"iam"`)
- `authToken` - Authentication token (string, optional - WARNING: stored in Nix store)
- `authTokenFile` - Path to file containing authentication token (path, optional - recommended for production)

### Authentication Methods

#### IAM Authentication (AWS EC2/ECS)

For AWS environments with IAM roles:

```nix
services.archil.mounts.my-disk = {
  diskName = "production-data";
  mountPoint = "/mnt/data";
  region = "us-east-1";
  authMethod = "iam";  # Uses EC2 instance profile or ECS task role
};
```

#### Token Authentication with File (Recommended for Production)

For secure token storage:

```nix
services.archil.mounts.my-disk = {
  diskName = "production-data";
  mountPoint = "/mnt/data";
  region = "us-east-1";
  authMethod = "token";
  authTokenFile = "/run/secrets/archil-token";  # Secure, not in Nix store
};
```

Works well with secrets management tools like:
- [agenix](https://github.com/ryantm/agenix)
- [sops-nix](https://github.com/Mic92/sops-nix)
- systemd encrypted credentials

#### Token Authentication with Direct Token (Development Only)

For testing and development:

```nix
services.archil.mounts.dev-disk = {
  diskName = "dev-storage";
  mountPoint = "/mnt/dev";
  region = "us-east-1";
  authMethod = "token";
  authToken = "your-token-here";  # WARNING: This goes into the Nix store!
};
```

**Security Warning**: The module will emit a warning when using `authToken` directly, as it stores the token in the world-readable Nix store.

### Managing Mounts with systemd

Each mount generates a systemd service named `archil-mount-<name>.service`:

```bash
# Check mount status
systemctl status archil-mount-data-disk

# Restart a mount
systemctl restart archil-mount-data-disk

# View mount logs
journalctl -u archil-mount-data-disk

# Stop a mount
systemctl stop archil-mount-data-disk
```

### Configuration Validation

The module validates your configuration at evaluation time and will error if:
- Mount point is not an absolute path
- Token authentication is configured without `authToken` or `authTokenFile`
- Both `authToken` and `authTokenFile` are set simultaneously
- Multiple mounts use the same mount point
- No mounts are configured when `services.archil.enable = true`

## Usage

### Manual Usage (Without NixOS Module)

If you're using the package without the NixOS module, here's how to use Archil manually:

### 1. Authentication

Before mounting, you need to authenticate. Archil supports multiple authentication methods:

- **Email/Password**: Interactive login
- **API Key**: Non-interactive (recommended for servers)
- **OAuth**: Web-based authentication

See [Archil Console](https://console.archil.com) for authentication setup.

### 2. Mount a Disk

Basic mount command:

```bash
sudo archil mount <user@email.com>/<disk-name> /mnt/archil --region <region>
```

**Example** (using the disk from your console):

```bash
# Create mount point
sudo mkdir -p /mnt/archil

# Mount the disk
sudo archil mount conneroisu@outlook.com/connix-t /mnt/archil --region aws-us-east-1

# Verify the mount
df -h /mnt/archil
```

### 3. Use Your Mounted Storage

```bash
# Write files
echo "Hello from Archil!" | sudo tee /mnt/archil/test.txt

# Read files
cat /mnt/archil/test.txt

# List contents
ls -la /mnt/archil/
```

### 4. Unmount

```bash
sudo archil unmount /mnt/archil
```

## Available Commands

```
archil mount              # Mount a disk to a local path
archil unmount            # Unmount a disk
archil checkout           # Check out a disk for offline use
archil checkin            # Check in changes after offline use
archil delegations        # Manage access delegations
archil status             # Show disk and mount status
archil set-log-level      # Configure logging verbosity
archil set-cache-expiry   # Configure cache settings
archil version            # Show version information
```

## Comparison: Nix vs Traditional Installation

| Feature | Nix Flake | Traditional (curl \| sh) |
|---------|-----------|--------------------------|
| **Reproducibility** | ✅ Pinned versions, reproducible | ❌ "Latest" version, can change |
| **Dependency Management** | ✅ Automatic, isolated | ⚠️ Requires system libfuse2 |
| **Rollback** | ✅ Easy with Nix generations | ❌ Manual reinstall |
| **Multi-version** | ✅ Can run multiple versions | ❌ Only one system-wide |
| **NixOS Integration** | ✅ Native | ⚠️ Works but not declarative |
| **Setup Complexity** | ⚠️ Requires Nix knowledge | ✅ Single command |
| **CI/CD** | ✅ Ideal for reproducible builds | ⚠️ Version drift risk |

**Recommendation:**
- **Use Nix Flake** if you're on NixOS or using Nix for development
- **Use Traditional** for quick setups on standard Linux distributions

## Requirements

### Nix Flake Method
- Nix with flakes enabled (Nix 2.4+)
- One of: x86_64-linux, aarch64-linux
- All dependencies (FUSE2, OpenSSL, libcap) are handled automatically

### Traditional Method
- Linux kernel 5.1+
- libfuse2 (FUSE version 2.x)
- Root or sudo access for mounting

## Troubleshooting

### "FUSE not available" Error

**Nix users:** The package includes FUSE2 automatically, but you may need to enable FUSE in your kernel:

```nix
# In your NixOS configuration:
boot.kernelModules = [ "fuse" ];
```

**Traditional users:** Install libfuse2:

```bash
# Debian/Ubuntu
sudo apt install fuse libfuse2

# Fedora/RHEL
sudo dnf install fuse fuse-libs

# Arch Linux
sudo pacman -S fuse2
```

### Permission Denied

Archil requires root privileges to mount filesystems:

```bash
sudo archil mount ...
```

Or add your user to the `fuse` group:

```bash
sudo usermod -a -G fuse $USER
```

### Authentication Failed

1. Verify your credentials at [Archil Console](https://console.archil.com)
2. Ensure you're using the correct region (`--region aws-us-east-1`)
3. Check disk name format: `email@domain.com/disk-name`

## Development

### Local Development

```bash
# Clone the repository
git clone https://github.com/conneroisu/archil-flake.git
cd archil-flake

# Build
nix build .#archil

# Test
./result/bin/archil --version

# Enter development shell
nix develop
```

### Updating the Package

#### Automated Updates (Recommended)

This repository uses a GitHub Actions workflow that automatically checks for new Archil versions every Monday at 00:00 UTC. When a new version is detected:

1. The workflow runs `./update.sh` to update version and hashes
2. A pull request is automatically created with the changes
3. Comprehensive validation runs on multiple architectures:
   - x86_64-linux build test
   - aarch64-linux build test
   - Nix flake validation
   - Code formatting verification
4. If all checks pass, the PR is automatically merged

You can also trigger the update workflow manually:
- Go to the "Actions" tab in GitHub
- Select "Update Archil Version"
- Click "Run workflow"

#### Manual Updates

To manually update to a newer Archil version:

1. Run the update script:
```bash
./update.sh --verbose
```

The script will automatically:
- Fetch the latest version from upstream
- Verify packages exist for both architectures
- Compute SHA256 hashes using `nix-prefetch-url`
- Update `flake.nix` with new version and hashes

2. Test the build:
```bash
nix build .#archil
./result/bin/archil --version
```

3. Commit and push:
```bash
git add flake.nix
git commit -m "chore: update archil to X.Y.Z-TIMESTAMP"
git push
```

Alternatively, you can manually update:
1. Update the version number in `flake.nix:84`
2. Fetch new hashes:

```bash
# x86_64
nix-prefetch-url https://s3.amazonaws.com/archil-client/pkg/archil-<VERSION>.x86_64.rpm

# aarch64
nix-prefetch-url https://s3.amazonaws.com/archil-client/pkg/archil-<VERSION>.aarch64.rpm
```

3. Update the `sha256` hashes in `flake.nix:91-94`
4. Rebuild and test

## License

The Archil client binary is proprietary software by Archil, Inc. This Nix flake packaging is provided as-is for convenience.

## Resources

- [Archil Homepage](https://archil.com)
- [Archil Console](https://console.archil.com)
- [Archil Documentation](https://docs.archil.com)
- [GitHub Repository](https://github.com/conneroisu/archil-flake)

## Contributing

Contributions are welcome! Please open an issue or pull request on GitHub.
