{
  description = "flake for https://archil.com/ linux installables";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    treefmt-nix,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [];
      };

      rooted = exec:
        builtins.concatStringsSep "\n"
        [
          ''REPO_ROOT="$(git rev-parse --show-toplevel)"''
          exec
        ];

      scripts = {
        dx = {
          exec = rooted ''$EDITOR "$REPO_ROOT"/flake.nix'';
          description = "Edit flake.nix";
        };
        gx = {
          exec = rooted ''$EDITOR "$REPO_ROOT"/go.mod'';
          description = "Edit go.mod";
        };
      };

      scriptPackages =
        pkgs.lib.mapAttrs
        (
          name: script:
            pkgs.writeShellApplication {
              inherit name;
              text = script.exec;
              runtimeInputs = script.deps or [];
            }
        )
        scripts;

      treefmtModule = {
        projectRootFile = "flake.nix";
        programs = {
          alejandra.enable = true; # Nix formatter
          gofmt.enable = true; # Go formatter
          golines.enable = true; # Go formatter (Shorter lines)
          goimports.enable = true; # Go formatter (Organize/Clean imports)
        };
      };
    in {
      devShells.default = pkgs.mkShell {
        name = "dev";

        # Available packages on https://search.nixos.org/packages
        packages = with pkgs;
          [
            alejandra # Nix
            nixd
            statix
            deadnix
          ]
          ++ builtins.attrValues scriptPackages;
      };

      packages = {
        default = self.packages.${system}.archil;
        archil = pkgs.stdenv.mkDerivation rec {
          pname = "archil-client";
          version = "0.6.4-1760484228";

          src = pkgs.fetchurl {
            url =
              if pkgs.stdenv.hostPlatform.isAarch64
              then "https://s3.amazonaws.com/archil-client/pkg/archil-${version}.aarch64.rpm"
              else "https://s3.amazonaws.com/archil-client/pkg/archil-${version}.x86_64.rpm";
            sha256 =
              if pkgs.stdenv.hostPlatform.isAarch64
              then "1mjwxpxfhbr7853792g9vfhpqscy0kaj2m4hn8hx7kn2j1yyva9k"
              else "17x7bgiq0r218rn3rp7li8ahnz4cf4mwkxmv34ri7cscv21fff6l";
          };

          nativeBuildInputs = with pkgs; [
            rpm
            cpio
            autoPatchelfHook
            makeWrapper
          ];

          buildInputs = with pkgs; [
            fuse
            openssl
            libcap
            stdenv.cc.cc.lib
          ];

          unpackPhase = ''
            runHook preUnpack
            rpm2cpio $src | cpio -idmv
            runHook postUnpack
          '';

          installPhase = ''
            runHook preInstall
            mkdir -p $out/bin
            if [ -f usr/bin/archil ]; then
              cp usr/bin/archil $out/bin/archil
            elif [ -f bin/archil ]; then
              cp bin/archil $out/bin/archil
            else
              echo "Error: Could not find archil binary in RPM"
              find . -name "archil" -type f
              exit 1
            fi
            runHook postInstall
          '';

          postFixup = ''
            wrapProgram $out/bin/archil \
              --prefix LD_LIBRARY_PATH : ${pkgs.lib.makeLibraryPath [pkgs.fuse pkgs.openssl pkgs.libcap]}
          '';

          meta = with pkgs.lib; {
            description = "Archil Storage Client - FUSE-based distributed storage filesystem";
            homepage = "https://archil.com";
            license = licenses.unfree;
            platforms = ["x86_64-linux" "aarch64-linux"];
            maintainers = [];
          };
        };
      };

      formatter = treefmt-nix.lib.mkWrapper pkgs treefmtModule;
    });
}
