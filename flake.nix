{
  description = "Redmine MCP by moonbit";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nur-packages = {
      url = "github:Omochice/nur-packages";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    moonbit-overlay = {
      url = "github:moonbit-community/moonbit-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    moon-nix = {
      url = "github:Omochice/moon-nix/fix-moon-compat";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.moonbit-overlay.follows = "moonbit-overlay";
    };
    mooncake-index = {
      url = "git+https://mooncakes.io/git/index";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      treefmt-nix,
      flake-utils,
      nur-packages,
      git-hooks,
      moonbit-overlay,
      moon-nix,
      mooncake-index,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            nur-packages.overlays.default
            moonbit-overlay.overlays.default
          ];
        };
        # moonbit-overlay publishes toolchains only for aarch64-darwin and x86_64-linux.
        moonbitToolchain = pkgs.lib.optional (pkgs.moonbit-bin ? latest) pkgs.moonbit-bin.latest;
        treefmt = treefmt-nix.lib.evalModule pkgs (
          { ... }:
          let
            rumdlConfig = (pkgs.formats.toml { }).generate "rumdl.toml" {
              # keep-sorted start
              MD004.style = "dash";
              MD007.indent = 4;
              MD007.style = "fixed";
              MD041.enabled = false;
              MD049.style = "underscore";
              MD050.style = "asterisk";
              MD055.style = "leading-and-trailing";
              MD060.enabled = true;
              MD060.style = "aligned";
              MD077.enabled = false;
              global.line_length = 0;
              # keep-sorted end
            };
          in
          {
            settings.global.excludes = [ "CHANGELOG.md" ];
            settings.formatter.moonfmt = pkgs.lib.mkIf (moonbitToolchain != [ ]) {
              command = pkgs.lib.getExe (
                pkgs.writeShellApplication {
                  name = "moonfmt-each";
                  runtimeInputs = moonbitToolchain;
                  text = ''
                    for file in "$@"; do
                      moonfmt -w "$file"
                    done
                  '';
                }
              );
              includes = [
                "*.mbt"
                "moon.mod"
                "moon.pkg"
              ];
            };
            settings.formatter.rumdl-format.options = [
              "--config"
              (toString rumdlConfig)
            ];
            programs = {
              # keep-sorted start block=yes
              keep-sorted.enable = true;
              nixfmt.enable = true;
              rumdl-format.enable = true;
              toml-sort.enable = true;
              yamlfmt = {
                enable = true;
                settings = {
                  formatter = {
                    type = "basic";
                    retain_line_breaks_single = true;
                  };
                };
              };
              # keep-sorted end
            };
          }
        );
        pre-commit-check = git-hooks.lib.${system}.run {
          src = ./.;
          package = pkgs.prek;
          hooks = {
            # Claude Code sets CLAUDECODE; humans are covered by the pre-push hook
            gitleaks-commit = {
              enable = true;
              name = "gitleaks (claude commit)";
              entry = pkgs.lib.getExe (
                pkgs.writeShellApplication {
                  name = "gitleaks-when-claude";
                  runtimeInputs = [ pkgs.gitleaks ];
                  text = ''
                    if [ -z "''${CLAUDECODE:-}" ]; then
                      exit 0
                    fi
                    gitleaks git --pre-commit --staged --no-banner --redact
                  '';
                }
              );
              pass_filenames = false;
              stages = [ "pre-commit" ];
            };
            gitleaks-push = {
              enable = true;
              name = "gitleaks";
              entry = "${pkgs.lib.getExe pkgs.gitleaks} git --no-banner --redact";
              pass_filenames = false;
              stages = [ "pre-push" ];
            };
            treefmt = {
              enable = true;
              packageOverrides.treefmt = treefmt.config.build.wrapper;
              stages = [ "pre-push" ];
            };
          };
        };
        devPackages = rec {
          # keep-sorted start block=yes
          actions = with pkgs; [
            actionlint
            ghalint
            zizmor
          ];
          coverage = [ pkgs.octocov ];
          moonbit = moonbitToolchain;
          # keep-sorted end
          default = [
            pkgs.go-task
            treefmt.config.build.wrapper
          ]
          ++ actions
          ++ coverage
          ++ moonbit;
        };
      in
      {
        # keep-sorted start block=yes
        checks = {
          # keep-sorted start
          actions =
            pkgs.runCommand "check-actions"
              {
                buildInputs = with pkgs; [
                  actionlint
                  ghalint
                  zizmor
                ];
                src = self;
              }
              ''
                cd $src
                actionlint -config-file .github/actionlint.yaml .github/**/*.{yaml,yml}
                ghalint run
                zizmor .github/workflows .github/actions
                touch $out
              '';
          formatting = treefmt.config.build.check self;
          pre-commit = pre-commit-check;
          renovate =
            pkgs.runCommand "validate-renovate-config"
              {
                buildInputs = with pkgs; [
                  renovate
                ];
                src = self;
              }
              ''
                cd $src
                renovate-config-validator --strict renovate.json5
                touch $out
              '';
          # keep-sorted end
        };
        devShells = pkgs.lib.pipe devPackages [
          (pkgs.lib.attrsets.mapAttrs (
            name: buildInputs:
            pkgs.mkShell (
              {
                buildInputs =
                  buildInputs
                  ++ pre-commit-check.enabledPackages
                  ++ pkgs.lib.optional pkgs.stdenv.hostPlatform.isDarwin pkgs.llvmPackages.lld;
                inherit (pre-commit-check) shellHook;
              }
              # nixpkgs' ld64 cannot build compact unwind info for moonc's output and
              # prints a warning per function; lld from the same LLVM release builds it.
              // pkgs.lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
                NIX_CFLAGS_LINK = "-fuse-ld=lld";
              }
            )
          ))
        ];
        formatter = treefmt.config.build.wrapper;
        packages = pkgs.lib.optionalAttrs (moonbitToolchain != [ ]) rec {
          redmoon =
            let
              project =
                (moon-nix.lib.mkMoonNix {
                  inherit pkgs;
                  toolchain = builtins.head moonbitToolchain;
                }).buildProject
                  {
                    src = ./.;
                    mainPackage = "omochice/redmoon/cmd/redmoon";
                    target = "native";
                    registry = mooncake-index;
                  };
            in
            # The linked binary embeds store paths of its build inputs.
            # Removing them keeps the toolchain and sources out of the runtime closure.
            pkgs.runCommandCC "redmoon"
              {
                nativeBuildInputs = [ pkgs.removeReferencesTo ];
                meta.mainProgram = "redmoon";
              }
              ''
                mkdir -p $out/bin
                install -m755 ${project}/bin/main $out/bin/redmoon
                $STRIP -S $out/bin/redmoon
                for ref in $(grep -ao '${builtins.storeDir}/[a-z0-9]\{32\}-[^/[:space:]]*' $out/bin/redmoon | sort -u); do
                  remove-references-to -t "$ref" $out/bin/redmoon
                done
              '';
          default = redmoon;
        };
        # keep-sorted end
      }
    );
}
