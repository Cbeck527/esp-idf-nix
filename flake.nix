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
      lib = nixpkgs.lib;
      versionRegistry = import ./data/versions.nix;
      latestByMajor = versionRegistry.latestByMajor;
      supportedMajors = builtins.attrNames latestByMajor;

      envLib = import ./pkgs/mk-esp-idf-env.nix {
        inherit nixpkgs versionRegistry;
      };

      majorName = major: "v${major}";
      majorToolsName = major: "${majorName major}-tools";
      majorTemplatePath = major: ./templates + "/v${major}";
    in
    {
      lib = {
        inherit (versionRegistry) latestByMajor knownVersions;
        inherit (envLib)
          mkEspIdfEnv
          mkEspIdfEnvForMajor
          mkEspIdfEnvFromUpstream
          ;
      };

      templates = builtins.listToAttrs (
        map (
          major:
          {
            name = majorName major;
            value = {
              path = majorTemplatePath major;
              description = "ESP-IDF ${latestByMajor.${major}} project with Nix devShell";
            };
          }
        ) supportedMajors
      );
    }
    // flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        eim = import ./pkgs/eim.nix { inherit pkgs system; };
        prefetchVersion = import ./pkgs/prefetch-version.nix {
          inherit pkgs;
          nixpkgsPath = nixpkgs.outPath;
        };
        envsByMajor = builtins.mapAttrs (
          _major: version: envLib.mkEspIdfEnv { inherit system version; }
        ) latestByMajor;

        majorShells =
          builtins.listToAttrs (
            map (
              major:
              {
                name = majorName major;
                value = envsByMajor.${major}.devShells.full;
              }
            ) supportedMajors
          )
          // builtins.listToAttrs (
            map (
              major:
              {
                name = majorToolsName major;
                value = envsByMajor.${major}.devShells.default;
              }
            ) supportedMajors
          );

        versionedPackagesForMajor =
          major:
          let
            env = envsByMajor.${major};
          in
          {
            "esp-idf-v${major}" = env.esp-idf;
            "xtensa-esp-elf-v${major}" = env.espTools.xtensa-esp-elf;
            "xtensa-esp-elf-gdb-v${major}" = env.espTools.xtensa-esp-elf-gdb;
            "riscv32-esp-elf-v${major}" = env.espTools.riscv32-esp-elf;
            "riscv32-esp-elf-gdb-v${major}" = env.espTools.riscv32-esp-elf-gdb;
            "openocd-esp32-v${major}" = env.espTools.openocd-esp32;
            "esp32ulp-elf-v${major}" = env.espTools.esp32ulp-elf;
            "esp-rom-elfs-v${major}" = env.espTools.esp-rom-elfs;
          };

        majorPackages = lib.foldl' (
          acc: major: acc // versionedPackagesForMajor major
        ) { } supportedMajors;
      in
      {
        packages = majorPackages // {
          inherit eim;
          prefetch-version = prefetchVersion;
        };
        devShells = majorShells;
        apps = {
          prefetch-version = flake-utils.lib.mkApp {
            drv = prefetchVersion;
          };
        };
      }
    );
}
