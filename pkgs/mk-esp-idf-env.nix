{
  nixpkgs,
  versionRegistry,
}:

let
  supportedMajors = builtins.attrNames versionRegistry.latestByMajor;

  espPlatforms = {
    x86_64-linux = "linux-amd64";
    aarch64-linux = "linux-arm64";
    aarch64-darwin = "macos-arm64";
  };

  mkPkgs =
    system:
    import nixpkgs {
      inherit system;
      # esptool 4.x (ESP-IDF v5) depends on ecdsa, which nixpkgs marks insecure (CVE-2024-23342).
      config.allowInsecurePredicate = pkg: (pkg.pname or "") == "ecdsa";
    };

  getKnownVersion =
    version:
    if builtins.hasAttr version versionRegistry.knownVersions then
      versionRegistry.knownVersions.${version}
    else
      null;

  getLatestVersionForMajor =
    major:
    if builtins.hasAttr major versionRegistry.latestByMajor then
      versionRegistry.latestByMajor.${major}
    else
      throw ''
        Unknown ESP-IDF major ${major} for lib.mkEspIdfEnvForMajor.

        Supported majors: ${builtins.concatStringsSep ", " supportedMajors}
      '';

  normalizeVersion =
    version:
    let
      versionMatch = builtins.match "^([0-9]+\\.[0-9]+(\\.[0-9]+)?)([-+][0-9A-Za-z.-]+)?$" version;
    in
    if versionMatch == null then
      throw "Invalid ESP-IDF version '${version}'. Use a numeric release such as 5.5.4 or 6.0.2, with an optional prerelease suffix."
    else
      builtins.elemAt versionMatch 0;

  validateVersion =
    {
      version,
      pkgs,
    }:
    let
      numericVersion = normalizeVersion version;
      profiles = import ./python-profiles.nix {
        inherit pkgs;
        lib = pkgs.lib;
      };
      releaseLine = profiles.releaseLineFor numericVersion;
    in
    if !(builtins.elem releaseLine profiles.supportedReleaseLines) then
      throw "Unsupported ESP-IDF Python profile '${releaseLine}' for version ${version}. Ask a maintainer to add and validate that profile before using it. Supported profiles: ${builtins.concatStringsSep ", " profiles.supportedReleaseLines}."
    else
      version;

  loadToolsJson =
    toolsJson:
    let
      kind = builtins.typeOf toolsJson;
    in
    if kind == "path" then
      builtins.fromJSON (builtins.readFile toolsJson)
    else if kind == "string" then
      builtins.fromJSON toolsJson
    else if kind == "set" then
      toolsJson
    else
      throw "toolsJson must be a path, JSON string, or parsed attrset";

  mkEnv =
    {
      system,
      version,
      srcHash,
      constraintsFile,
      toolsJson,
      pkgs ? mkPkgs system,
    }:
    let
      lib = pkgs.lib;
      normalizedVersion = normalizeVersion version;

      espPlatform =
        if builtins.hasAttr system espPlatforms then
          espPlatforms.${system}
        else
          throw "Unsupported system for ESP-IDF tools: ${system}";

      eim = import ./eim.nix {
        inherit pkgs system;
      };

      espTools = import ./esp-tools.nix {
        inherit
          pkgs
          lib
          espPlatform
          toolsJson
          ;
        pythonEnv = espPython.pythonEnv;
      };

      espPython = import ./python-packages.nix {
        inherit
          pkgs
          lib
          ;
        espIdfVersion = normalizedVersion;
        inherit constraintsFile;
      };

      esp-idf = import ./esp-idf.nix {
        inherit
          pkgs
          lib
          version
          ;
        idfSrc = pkgs.fetchFromGitHub {
          owner = "espressif";
          repo = "esp-idf";
          rev = "v${version}";
          fetchSubmodules = true;
          hash = srcHash;
        };
      };

      commonPackages =
        (with pkgs; [
          cmake
          ninja
          espPython.pythonEnv
          git
          flex
          bison
          gperf
          dfu-util
        ])
        ++ builtins.attrValues espTools;

      shellSetup = ''
        export IDF_PYTHON_ENV_PATH="${espPython.pythonEnv}"
        export IDF_PYTHON_CHECK_CONSTRAINTS=no
        export IDF_TOOLS_PATH="''${IDF_TOOLS_PATH:-$HOME/.espressif}"
        mkdir -p "$IDF_TOOLS_PATH"
      '';
    in
    # Check the host before exposing any part of the environment.
    builtins.seq espPlatform {
      inherit
        eim
        esp-idf
        espTools
        espPython
        ;

      packages = {
        inherit eim esp-idf;
        default = eim;
      }
      // espTools;

      devShells = {
        default = pkgs.mkShell {
          packages = commonPackages;

          env = {
            ESP_ROM_ELF_DIR = "${espTools.esp-rom-elfs}";
            OPENOCD_SCRIPTS = "${espTools.openocd-esp32}/share/openocd/scripts";
          };

          shellHook = ''
            ${shellSetup}
            if [ -n "''${IDF_PATH:-}" ]; then
              if ! idf_version="$(${espPython.pythonEnv}/bin/python -c '
            import os
            import sys
            sys.path.insert(0, os.path.join(os.environ["IDF_PATH"], "tools"))
            from idf_py_actions.tools import idf_version
            version = idf_version()
            if version is None:
                raise SystemExit(1)
            print(version.removeprefix("v"))
            ')"; then
                echo "error: could not determine ESP-IDF version from IDF_PATH=$IDF_PATH" >&2
                exit 1
              fi
              export ESP_IDF_VERSION="$idf_version"
            fi
            echo "ESP-IDF development environment (tools only)"
            echo "Xtensa GCC:  $(xtensa-esp-elf-gcc --version | head -1)"
            echo "RISC-V GCC:  $(riscv32-esp-elf-gcc --version | head -1)"
            echo "OpenOCD:     $(openocd --version 2>&1 | head -1)"
            if [ -z "''${IDF_PATH:-}" ]; then
              echo ""
              echo "  NOTE: IDF_PATH not set. Set it before entering or re-entering this tools shell:"
              echo "    IDF_PATH=/path/to/your/esp-idf nix develop .#v5-tools"
              echo "    (use .#v6-tools for ESP-IDF 6)"
              echo "    or use a full shell such as 'nix develop .#v5' or '.#v6'"
            fi
          '';
        };

        full = pkgs.mkShell {
          packages = commonPackages;

          env = {
            IDF_PATH = "${esp-idf}";
            ESP_IDF_VERSION = version;
            ESP_ROM_ELF_DIR = "${espTools.esp-rom-elfs}";
            OPENOCD_SCRIPTS = "${espTools.openocd-esp32}/share/openocd/scripts";
          };

          shellHook = ''
            ${shellSetup}
            export PATH="${esp-idf}/tools:$PATH"

            export GIT_CONFIG_COUNT=''${GIT_CONFIG_COUNT:-0}
            export GIT_CONFIG_KEY_$GIT_CONFIG_COUNT=safe.directory
            export GIT_CONFIG_VALUE_$GIT_CONFIG_COUNT="${esp-idf}"
            export GIT_CONFIG_COUNT=$((GIT_CONFIG_COUNT + 1))

            echo "ESP-IDF v${version}"
            echo "IDF_PATH:    $IDF_PATH"
            echo "Xtensa GCC:  $(xtensa-esp-elf-gcc --version | head -1)"
            echo "RISC-V GCC:  $(riscv32-esp-elf-gcc --version | head -1)"
            echo "OpenOCD:     $(openocd --version 2>&1 | head -1)"
          '';
        };
      };
    };

  mkEspIdfEnv =
    {
      system,
      version,
      srcHash ? null,
      constraintsFile ? null,
      toolsJson ? null,
      pkgs ? mkPkgs system,
    }:
    let
      validatedVersion = validateVersion {
        inherit version pkgs;
      };
      knownVersion = getKnownVersion version;
      errorMessage = ''
        Unknown ESP-IDF version ${version} for lib.mkEspIdfEnv.

        Either:
          - register the version in lib.knownVersions
          - or pass srcHash, constraintsFile, and toolsJson explicitly
      '';

      resolvedSrcHash =
        if srcHash != null then
          srcHash
        else if knownVersion != null then
          knownVersion.srcHash
        else
          throw errorMessage;

      resolvedConstraintsFile =
        if constraintsFile != null then
          constraintsFile
        else if knownVersion != null then
          knownVersion.constraintsPath
        else
          throw errorMessage;

      resolvedToolsJson =
        if toolsJson != null then
          loadToolsJson toolsJson
        else if knownVersion != null then
          loadToolsJson knownVersion.toolsJsonPath
        else
          throw errorMessage;
    in
    builtins.seq validatedVersion (mkEnv {
      inherit pkgs system;
      version = validatedVersion;
      srcHash = resolvedSrcHash;
      constraintsFile = resolvedConstraintsFile;
      toolsJson = resolvedToolsJson;
    });

  mkEspIdfEnvForMajor =
    {
      system,
      major,
      pkgs ? mkPkgs system,
    }:
    mkEspIdfEnv {
      inherit
        pkgs
        system
        ;
      version = getLatestVersionForMajor major;
    };
in
{
  inherit
    mkEspIdfEnv
    mkEspIdfEnvForMajor
    ;
}
