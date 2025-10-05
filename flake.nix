{
  description = "Personal website for ghostbuster91";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    hugo-coder = {
      url = "github:luizdepra/hugo-coder";
      flake = false;
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    devshell.url = "github:numtide/devshell";
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];
      imports = [
        inputs.treefmt-nix.flakeModule
        inputs.devshell.flakeModule
        ({ self, inputs, ... }: {
          perSystem = { pkgs, ... }: {

            packages.website = pkgs.stdenv.mkDerivation {
              name = "website";
              src = self;
              buildInputs = [ pkgs.git pkgs.nodePackages.prettier ];
              buildPhase = ''
                mkdir -p themes
                ln -sfn ${inputs.hugo-coder} themes/hugo-coder
                sed -i -e 's/enableGitInfo = true/enableGitInfo = false/' hugo.toml
                ${pkgs.hugo}/bin/hugo
                ${pkgs.nodePackages.prettier}/bin/prettier -w public '!**/*.{js,css}'
              '';
              installPhase = "cp -r public $out";
            };

            apps = {
              default.program =
                let
                  wrapper = pkgs.writeShellApplication {
                    name = "hugo-serve";
                    runtimeInputs = [ pkgs.hugo ];
                    text = ''
                      set -euo pipefail
                      mkdir -p themes
                      ln -sfn ${inputs.hugo-coder} themes/hugo-coder
                      sed -i -e 's/enableGitInfo = true/enableGitInfo = false/' hugo.toml

                      exec hugo server --bind 0.0.0.0 --port 1313 -D "$@"
                    '';
                  };
                in
                "${wrapper}/bin/hugo-serve";
            };

            devshells.default = {
              packages = [
                pkgs.hugo
              ];
            };
          };
        })
      ];
      perSystem.treefmt = {
        imports = [ ./treefmt.nix ];
      };
    };
}
