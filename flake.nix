{
  description = "ESP-IDF Development Tools";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      nixpkgs,
      flake-utils,
      ...
    }:
    let
      versionRegistry = import ./data/versions.nix;

      envLib = import ./pkgs/mk-esp-idf-env.nix {
        inherit nixpkgs versionRegistry;
      };
    in
    {
      lib = {
        inherit (versionRegistry) defaultVersion knownVersions;
        inherit (envLib) mkEspIdfEnv mkEspIdfEnvFromUpstream;
      };

      templates.default = {
        path = ./templates/default;
        description = "ESP-IDF project with Nix devShell";
      };
    }
    // flake-utils.lib.eachDefaultSystem (
      system:
      let
        env = envLib.mkEspIdfEnv { inherit system; };
        pkgs = import nixpkgs { inherit system; };
        prefetchVersion = import ./pkgs/prefetch-version.nix {
          inherit pkgs;
          nixpkgsPath = nixpkgs.outPath;
        };
      in
      {
        packages = env.packages // {
          prefetch-version = prefetchVersion;
        };
        inherit (env) devShells;
        apps = {
          prefetch-version = flake-utils.lib.mkApp {
            drv = prefetchVersion;
          };
        };
      }
    );
}
