# Example NixOS configuration using the Archil module
#
# To use this module in your NixOS configuration:
#
# 1. Add this flake as an input in your flake.nix:
#    inputs.archil-flake.url = "github:conneroisu/archil-flake";
#
# 2. Import the module:
#    imports = [ inputs.archil-flake.nixosModules.default ];
#
# 3. Add the overlay to get the archil package:
#    nixpkgs.overlays = [ inputs.archil-flake.overlays.default ];
#
# 4. Configure your mounts as shown below
{
  config,
  pkgs,
  ...
}: {
  # Enable the Archil service
  services.archil = {
    enable = true;

    # Optional: Override the archil package
    # package = pkgs.archil;

    # Configure mounts
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

      # Example: Token-authenticated mount using direct token (NOT RECOMMENDED for production)
      # dev-disk = {
      #   diskName = "dev-storage";
      #   mountPoint = "/mnt/dev";
      #   region = "us-east-1";
      #   authMethod = "token";
      #   authToken = "your-token-here";  # WARNING: This goes into the Nix store!
      # };
    };
  };

  # The module automatically:
  # - Loads the FUSE kernel module
  # - Creates systemd services: archil-mount-data-disk.service, archil-mount-backup-disk.service
  # - Creates mount point directories if they don't exist
  # - Configures automatic restart on failure with exponential backoff
  # - Handles graceful unmount on service stop

  # You can manage the mounts using systemd:
  #   systemctl status archil-mount-data-disk
  #   systemctl restart archil-mount-backup-disk
  #   journalctl -u archil-mount-data-disk
}
