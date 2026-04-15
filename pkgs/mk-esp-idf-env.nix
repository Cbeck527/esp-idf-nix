{
  nixpkgs,
  versionRegistry,
}:

let
  permittedInsecurePackages = [
    "python3.13-ecdsa-0.19.1"
  ];

  supportedMajors = builtins.attrNames versionRegistry.latestByMajor;

  espPlatforms = {
    x86_64-linux = "linux-amd64";
    aarch64-linux = "linux-arm64";
    x86_64-darwin = "macos";
    aarch64-darwin = "macos-arm64";
  };

  mkPkgs =
    system:
    import nixpkgs {
      inherit system;
      config.permittedInsecurePackages = permittedInsecurePackages;
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
      constraintsHash,
      toolsJson,
      pkgs ? mkPkgs system,
      idfSrc ? null,
    }:
    let
      lib = pkgs.lib;

      espPlatform =
        if builtins.hasAttr system espPlatforms then
          espPlatforms.${system}
        else
          throw "Unsupported system for ESP-IDF tools: ${system}";

      resolvedIdfSrc =
        if idfSrc != null then
          idfSrc
        else
          pkgs.fetchFromGitHub {
            owner = "espressif";
            repo = "esp-idf";
            rev = "v${version}";
            fetchSubmodules = true;
            hash = srcHash;
          };

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
      };

      espPython = import ./python-packages.nix {
        inherit
          pkgs
          lib
          ;
        espIdfVersion = version;
      };

      esp-idf = import ./esp-idf.nix {
        inherit
          pkgs
          lib
          version
          constraintsHash
          ;
        idfSrc = resolvedIdfSrc;
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
          eim
        ])
        ++ builtins.attrValues espTools;
    in
    {
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
            echo "ESP-IDF development environment (tools only)"
            echo "Xtensa GCC:  $(xtensa-esp-elf-gcc --version | head -1)"
            echo "RISC-V GCC:  $(riscv32-esp-elf-gcc --version | head -1)"
            echo "OpenOCD:     $(openocd --version 2>&1 | head -1)"
            if [ -z "$IDF_PATH" ]; then
              echo ""
              echo "  NOTE: IDF_PATH not set. Either:"
              echo "    export IDF_PATH=/path/to/your/esp-idf"
              echo "    or use a full shell such as 'nix develop .#v5' or '.#v6'"
            fi
          '';
        };

        full = pkgs.mkShell {
          packages = commonPackages;

          env = {
            IDF_PATH = "${esp-idf}";
            IDF_TOOLS_PATH = "${esp-idf}/tools-path";
            IDF_PYTHON_ENV_PATH = "${espPython.pythonEnv}";
            ESP_IDF_VERSION = version;
            ESP_ROM_ELF_DIR = "${espTools.esp-rom-elfs}";
            OPENOCD_SCRIPTS = "${espTools.openocd-esp32}/share/openocd/scripts";
          };

          shellHook = ''
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
      constraintsHash ? null,
      toolsJson ? null,
    }:
    let
      knownVersion = getKnownVersion version;
      errorMessage = ''
        Unknown ESP-IDF version ${version} for lib.mkEspIdfEnv.

        Either:
          - register the version in lib.knownVersions
          - pass srcHash, constraintsHash, and toolsJson explicitly
          - or call lib.mkEspIdfEnvFromUpstream
      '';

      resolvedSrcHash =
        if srcHash != null then
          srcHash
        else if knownVersion != null then
          knownVersion.srcHash
        else
          throw errorMessage;

      resolvedConstraintsHash =
        if constraintsHash != null then
          constraintsHash
        else if knownVersion != null then
          knownVersion.constraintsHash
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
    mkEnv {
      inherit
        system
        version
        ;
      srcHash = resolvedSrcHash;
      constraintsHash = resolvedConstraintsHash;
      toolsJson = resolvedToolsJson;
    };

  mkEspIdfEnvForMajor =
    {
      system,
      major,
    }:
    mkEspIdfEnv {
      inherit system;
      version = getLatestVersionForMajor major;
    };

  mkEspIdfEnvFromUpstream =
    {
      system,
      version,
      srcHash ? null,
      constraintsHash ? null,
    }:
    let
      knownVersion = getKnownVersion version;

      resolvedSrcHash =
        if srcHash != null then
          srcHash
        else if knownVersion != null then
          knownVersion.srcHash
        else
          throw ''
            lib.mkEspIdfEnvFromUpstream requires srcHash for ESP-IDF ${version}.

            Run:
              nix run .#prefetch-version -- ${version}
          '';

      resolvedConstraintsHash =
        if constraintsHash != null then
          constraintsHash
        else if knownVersion != null then
          knownVersion.constraintsHash
        else
          throw ''
            lib.mkEspIdfEnvFromUpstream requires constraintsHash for ESP-IDF ${version}.

            Run:
              nix run .#prefetch-version -- ${version}
          '';

      pkgs = mkPkgs system;

      idfSrc = pkgs.fetchFromGitHub {
        owner = "espressif";
        repo = "esp-idf";
        rev = "v${version}";
        fetchSubmodules = true;
        hash = resolvedSrcHash;
      };

      toolsJson = builtins.fromJSON (builtins.readFile "${idfSrc}/tools/tools.json");
    in
    mkEnv {
      inherit
        pkgs
        idfSrc
        system
        version
        toolsJson
        ;
      srcHash = resolvedSrcHash;
      constraintsHash = resolvedConstraintsHash;
    };
in
{
  inherit
    mkEspIdfEnv
    mkEspIdfEnvForMajor
    mkEspIdfEnvFromUpstream
    ;
}
