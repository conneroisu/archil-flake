# Archil Storage Client - Nix Flake

[![CI Validation](https://github.com/conneroisu/archil-flake/actions/workflows/ci.yml/badge.svg)](https://github.com/conneroisu/archil-flake/actions/workflows/ci.yml)

Unofficial reproducible Nix package for the [Archil](https://archil.com) distributed storage client.

## What is Archil?

[Archil](https://docs.archil.com/getting-started/introduction) is a distributed storage service that allows you to mount cloud storage as a local filesystem using FUSE.

This flake packages the official Archil client binary for use with Nix and NixOS.

## Features

- ✅ Multi-architecture support (x86_64-linux, aarch64-linux)
- ✅ Automatic dependency management via autoPatchelfHook
- ✅ Reproducible builds with locked dependencies
- ✅ Declarative configuration for NixOS

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

Add to your `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    archil.url = "github:conneroisu/archil-flake";
  };

  outputs = { nixpkgs, archil, ... }: {
    nixosConfigurations.your-host = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        {
          environment.systemPackages = [
            archil.packages.x86_64-linux.archil
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

## Usage

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
