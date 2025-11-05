# NixOS VM test for the Archil module
# Run with: nix build .#checks.x86_64-linux.archil-module-test
{
  nixpkgs ? <nixpkgs>,
  system ? builtins.currentSystem,
}: let
  pkgs = import nixpkgs {
    inherit system;
    config.allowUnfree = true;
  };

  archilModule = import ./modules/archil.nix;

  # Create a mock archil package that simulates the mount command
  mockArchil = pkgs.writeShellScriptBin "archil" ''
    case "$1" in
      mount)
        echo "Mock archil mount: disk=$2 mountpoint=$3 args=''${@:4}"
        # Create a marker file to show the mount "succeeded"
        mkdir -p "$3"
        touch "$3/.archil-mounted"
        ;;
      unmount)
        echo "Mock archil unmount: mountpoint=$2"
        rm -f "$2/.archil-mounted"
        ;;
      *)
        echo "Mock archil: unknown command $1"
        exit 1
        ;;
    esac
  '';

  # Simple evaluation test
  evalTest = pkgs.lib.evalModules {
    modules = [
      ({...}: {
        # Provide minimal NixOS options needed by the module
        options = {
          boot.kernelModules = pkgs.lib.mkOption {type = pkgs.lib.types.listOf pkgs.lib.types.str;};
          environment.systemPackages = pkgs.lib.mkOption {type = pkgs.lib.types.listOf pkgs.lib.types.package;};
          systemd.services = pkgs.lib.mkOption {type = pkgs.lib.types.attrs;};
          assertions = pkgs.lib.mkOption {type = pkgs.lib.types.listOf pkgs.lib.types.attrs;};
          warnings = pkgs.lib.mkOption {type = pkgs.lib.types.listOf pkgs.lib.types.str;};
        };
      })
      archilModule
      {
        services.archil = {
          enable = true;
          package = mockArchil;
          mounts = {
            test-disk = {
              diskName = "test-disk-name";
              mountPoint = "/mnt/test";
              region = "us-east-1";
              authMethod = "iam";
            };
            token-disk = {
              diskName = "token-disk";
              mountPoint = "/mnt/token";
              region = "us-west-2";
              authMethod = "token";
              authToken = "test-token-123";
            };
          };
        };
      }
    ];
  };
in
  pkgs.runCommand "archil-module-test" {} ''
    # Validate module assertions first
    echo "Validating module assertions..."
    ${
      let
        failedAssertions = builtins.filter (a: !a.assertion) evalTest.config.assertions;
      in
        if builtins.length failedAssertions > 0
        then ''
          echo "ERROR: Module assertions failed:"
          ${builtins.concatStringsSep "\n" (map (a: "echo '  - ${a.message}'") failedAssertions)}
          exit 1
        ''
        else "echo 'Module assertions: OK'"
    }

    # Test that the module evaluates
    echo "Testing module evaluation..."
    if ${
      if evalTest.config.services.archil.enable
      then "true"
      else "false"
    }; then
      echo "Module enabled: OK"
    else
      echo "ERROR: Module is not enabled"
      exit 1
    fi

    # Test that systemd services were created
    if ${
      if evalTest.config.systemd.services ? "archil-mount-test-disk"
      then "true"
      else "false"
    }; then
      echo "IAM service created: OK"
    else
      echo "ERROR: IAM service 'archil-mount-test-disk' was not created"
      exit 1
    fi

    if ${
      if evalTest.config.systemd.services ? "archil-mount-token-disk"
      then "true"
      else "false"
    }; then
      echo "Token service created: OK"
    else
      echo "ERROR: Token service 'archil-mount-token-disk' was not created"
      exit 1
    fi

    # Test that FUSE module is loaded
    if ${
      if builtins.elem "fuse" evalTest.config.boot.kernelModules
      then "true"
      else "false"
    }; then
      echo "FUSE module loaded: OK"
    else
      echo "ERROR: FUSE kernel module is not loaded"
      exit 1
    fi

    # Test that package is in systemPackages
    if ${
      if builtins.elem mockArchil evalTest.config.environment.systemPackages
      then "true"
      else "false"
    }; then
      echo "Package installed: OK"
    else
      echo "ERROR: Archil package is not in systemPackages"
      exit 1
    fi

    # Test warnings for insecure token usage
    if ${
      if builtins.length evalTest.config.warnings > 0
      then "true"
      else "false"
    }; then
      echo "Security warning present: OK"
    else
      echo "ERROR: Expected security warning for authToken usage, but none found"
      exit 1
    fi

    echo "All tests passed!"
    touch $out
  ''
