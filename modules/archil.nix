{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.archil;

  # Submodule for individual mount configurations
  mountOptions = {
    options = {
      diskName = lib.mkOption {
        type = lib.types.str;
        description = "Name of the Archil disk to mount";
        example = "my-data-disk";
      };

      mountPoint = lib.mkOption {
        type = lib.types.str;
        description = "Absolute path where the disk should be mounted";
        example = "/mnt/archil-data";
      };

      region = lib.mkOption {
        type = lib.types.str;
        description = "Archil region where the disk is located";
        example = "us-east-1";
      };

      authMethod = lib.mkOption {
        type = lib.types.enum ["iam" "token"];
        default = "iam";
        description = ''
          Authentication method to use:
          - "iam": Use IAM role (AWS EC2 instance profile or ECS task role)
          - "token": Use static authentication token
        '';
      };

      authToken = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Authentication token for Archil (when authMethod is "token").
          WARNING: This will be stored in the Nix store, which is world-readable.
          For production use, prefer authTokenFile instead.
        '';
      };

      authTokenFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = ''
          Path to file containing the authentication token.
          The file should contain only the token, with no trailing whitespace.
          This is more secure than authToken as it doesn't put the token in the Nix store.
        '';
        example = "/run/secrets/archil-token";
      };
    };
  };

  # Generate systemd service for a mount
  mkMountService = name: mountCfg: let
    # Build the mount command based on auth method
    mountCommand =
      if mountCfg.authMethod == "token"
      then
        if mountCfg.authTokenFile != null
        then
          # Use systemd credential from file
          "${cfg.package}/bin/archil mount ${lib.escapeShellArg mountCfg.diskName} ${lib.escapeShellArg mountCfg.mountPoint} --region ${lib.escapeShellArg mountCfg.region} --auth-token $(cat $CREDENTIALS_DIRECTORY/archil-token)"
        else
          # Use token directly (from authToken option)
          "${cfg.package}/bin/archil mount ${lib.escapeShellArg mountCfg.diskName} ${lib.escapeShellArg mountCfg.mountPoint} --region ${lib.escapeShellArg mountCfg.region} --auth-token ${lib.escapeShellArg mountCfg.authToken}"
      else
        # IAM authentication (no token needed)
        "${cfg.package}/bin/archil mount ${lib.escapeShellArg mountCfg.diskName} ${lib.escapeShellArg mountCfg.mountPoint} --region ${lib.escapeShellArg mountCfg.region}";

    # Unmount script with fallback
    unmountScript = pkgs.writeShellScript "archil-unmount-${name}" ''
      ${cfg.package}/bin/archil unmount ${lib.escapeShellArg mountCfg.mountPoint} || \
      ${pkgs.util-linux}/bin/umount ${lib.escapeShellArg mountCfg.mountPoint}
    '';
  in
    lib.nameValuePair "archil-mount-${name}" {
      description = "Archil FUSE mount for ${mountCfg.diskName} at ${mountCfg.mountPoint}";
      after = ["network-online.target"];
      wants = ["network-online.target"];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        Type = "forking";
        ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p ${lib.escapeShellArg mountCfg.mountPoint}";
        ExecStart = mountCommand;
        ExecStop = unmountScript;
        Restart = "on-failure";
        RestartSec = "10s";
        RestartMaxDelaySec = "5min";
        TimeoutStopSec = "30s";

        # Security hardening
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [mountCfg.mountPoint];

        # Load credential from file if using token auth with file
        LoadCredential = lib.optionalString (mountCfg.authMethod == "token" && mountCfg.authTokenFile != null) "archil-token:${mountCfg.authTokenFile}";
      };
    };

  # Collect all mount points to check for duplicates
  allMountPoints = lib.mapAttrsToList (name: mountCfg: mountCfg.mountPoint) cfg.mounts;

  # Validation assertions
  mountAssertions =
    lib.mapAttrsToList (name: mountCfg: [
      {
        assertion = lib.hasPrefix "/" mountCfg.mountPoint;
        message = "services.archil.mounts.${name}.mountPoint must be an absolute path (got: ${mountCfg.mountPoint})";
      }
      {
        assertion = mountCfg.authMethod == "token" -> (mountCfg.authToken != null || mountCfg.authTokenFile != null);
        message = "services.archil.mounts.${name}: when authMethod is 'token', either authToken or authTokenFile must be set";
      }
      {
        assertion = !(mountCfg.authToken != null && mountCfg.authTokenFile != null);
        message = "services.archil.mounts.${name}: cannot set both authToken and authTokenFile, choose one";
      }
    ])
    cfg.mounts;

  # Flatten the list of lists
  flattenedAssertions = lib.flatten mountAssertions;
in {
  options.services.archil = {
    enable = lib.mkEnableOption "Archil FUSE filesystem service";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.archil or (throw "Archil package not available. Make sure the archil-flake is properly imported.");
      defaultText = lib.literalExpression "pkgs.archil";
      description = "The Archil package to use";
    };

    mounts = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule mountOptions);
      default = {};
      description = ''
        Attribute set of Archil mounts to configure.
        Each attribute name becomes part of the systemd service name: archil-mount-<name>.service
      '';
      example = lib.literalExpression ''
        {
          data-disk = {
            diskName = "production-data";
            mountPoint = "/mnt/data";
            region = "us-east-1";
            authMethod = "iam";
          };
          backup-disk = {
            diskName = "backup-storage";
            mountPoint = "/mnt/backup";
            region = "us-west-2";
            authMethod = "token";
            authTokenFile = "/run/secrets/archil-token";
          };
        }
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Validation assertions
    assertions =
      flattenedAssertions
      ++ [
        {
          assertion = cfg.mounts != {};
          message = "services.archil.enable is true but no mounts are configured in services.archil.mounts";
        }
        {
          assertion = lib.length allMountPoints == lib.length (lib.unique allMountPoints);
          message = "services.archil.mounts: duplicate mount points detected. Each mount must have a unique mountPoint.";
        }
      ];

    # Warnings for insecure configurations
    warnings =
      lib.optional
      (lib.any (mountCfg: mountCfg.authToken != null) (lib.attrValues cfg.mounts))
      "services.archil: using authToken puts the token in the world-readable Nix store. For production, use authTokenFile instead.";

    # Load FUSE kernel module
    boot.kernelModules = ["fuse"];

    # Ensure FUSE is available
    environment.systemPackages = [cfg.package];

    # Generate systemd services for each mount
    systemd.services = lib.mapAttrs' mkMountService cfg.mounts;
  };
}
