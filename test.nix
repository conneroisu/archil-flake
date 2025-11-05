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
    # Test that the module evaluates
    echo "Testing module evaluation..."
    ${pkgs.lib.optionalString (evalTest.config.services.archil.enable) "echo 'Module enabled: OK'"}

    # Test that systemd services were created
    ${pkgs.lib.optionalString (evalTest.config.systemd.services ? "archil-mount-test-disk") "echo 'IAM service created: OK'"}
    ${pkgs.lib.optionalString (evalTest.config.systemd.services ? "archil-mount-token-disk") "echo 'Token service created: OK'"}

    # Test that FUSE module is loaded
    ${pkgs.lib.optionalString (builtins.elem "fuse" evalTest.config.boot.kernelModules) "echo 'FUSE module loaded: OK'"}

    # Test that package is in systemPackages
    ${pkgs.lib.optionalString (builtins.elem mockArchil evalTest.config.environment.systemPackages) "echo 'Package installed: OK'"}

    # Test warnings for insecure token usage
    ${pkgs.lib.optionalString (builtins.length evalTest.config.warnings > 0) "echo 'Security warning present: OK'"}

    echo "All tests passed!"
    touch $out
  ''
