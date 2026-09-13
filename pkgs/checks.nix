{
  pkgs,
  envsByMajor,
  prefetchVersion,
}:

let
  lib = pkgs.lib;
  majors = builtins.attrNames envsByMajor;
  basicTools = with pkgs; [
    bash
    coreutils
    findutils
    gawk
    gnugrep
    which
  ];

  # mkShell merges its `env` argument into the derivation attributes.  Keep
  # every exported environment variable, including the less obvious ROM and
  # OpenOCD paths, while leaving package and derivation attributes alone.
  shellEnvironment =
    shell:
    lib.map (name: "export ${name}=${lib.escapeShellArg shell.${name}}") (
      lib.filter (name: builtins.match "[A-Z][A-Z0-9_]*" name != null) (builtins.attrNames shell)
    );

  shellInit =
    name: shell:
    pkgs.writeShellScript name ''
      ${lib.concatStringsSep "\n" (shellEnvironment shell)}
      export PATH="${lib.makeBinPath (basicTools ++ shell.nativeBuildInputs ++ shell.buildInputs)}:$PATH"
      ${shell.shellHook}
    '';

  mkRuntimeCheck =
    major:
    let
      env = envsByMajor.${major};
      otherMajor = lib.findFirst (candidate: candidate != major) major majors;
      otherEnv = envsByMajor.${otherMajor};
      fullInit = shellInit "esp-idf-v${major}-full-init" env.devShells.full;
      toolsInit = shellInit "esp-idf-v${major}-tools-init" env.devShells.default;
      v5FullInit = shellInit "esp-idf-v5-full-init" envsByMajor."5".devShells.full;
      v6FullInit = shellInit "esp-idf-v6-full-init" envsByMajor."6".devShells.full;
      allPackages = [
        env.esp-idf
        env.espPython.pythonEnv
        otherEnv.esp-idf
        otherEnv.espPython.pythonEnv
      ]
      ++ builtins.attrValues env.espTools
      ++ builtins.attrValues otherEnv.espTools
      ++ basicTools;
    in
    pkgs.runCommand "esp-idf-v${major}-runtime"
      {
        nativeBuildInputs = allPackages;
        IDF_PATH = "${env.esp-idf}";
        IDF_PYTHON_ENV_PATH = "${env.espPython.pythonEnv}";
        ESP_IDF_CONSTRAINTS = "${env.espPython.constraintsFile}";
        ESP_IDF_PYTHON_VERSION = pkgs.python3.pythonVersion;
        ESP_IDF_ESPTOOL_VERSION = env.espPython.esptool.version;
        ESP_IDF_VERSION_EXPECTED = env.esp-idf.version;
        ESP_IDF_MAJOR = major;
        FULL_INIT = fullInit;
        TOOLS_INIT = toolsInit;
        V5_FULL_INIT = v5FullInit;
        V6_FULL_INIT = v6FullInit;
        ARCHIVE_CHECK = ./../tests/archive.bash;
        BASE_PATH = lib.makeBinPath basicTools;
      }
      ''
        export TMPDIR="$TMPDIR/runtime"
        mkdir -p "$TMPDIR"
        env -i PATH="$BASE_PATH" HOME="$TMPDIR/archive-home" FULL_INIT="$FULL_INIT" \
          ARCHIVE_CHECK="$ARCHIVE_CHECK" TMPDIR="$TMPDIR" bash -c '
            set -euo pipefail
            source "$FULL_INIT"
            bash "$ARCHIVE_CHECK"
          ' bash
        bash ${./../tests/runtime.bash}
        touch "$out"
      '';

  mkFirmwareCheck =
    major: target:
    let
      env = envsByMajor.${major};
      fullInit = shellInit "esp-idf-v${major}-${target}-full-init" env.devShells.full;
      firmwareTools = [
        env.esp-idf
        env.espPython.pythonEnv
      ]
      ++ builtins.attrValues env.espTools
      ++ (with pkgs; [
        bash
        cmake
        coreutils
        findutils
        git
        gawk
        gnugrep
        ninja
        which
      ]);
    in
    pkgs.runCommand "esp-idf-v${major}-${target}-firmware"
      {
        nativeBuildInputs = firmwareTools;
        FULL_INIT = fullInit;
        TEMPLATE_PATH = ./../templates/v${major};
        TARGET = target;
        BASE_PATH = lib.makeBinPath firmwareTools;
      }
      ''
        export TMPDIR="$TMPDIR/firmware"
        mkdir -p "$TMPDIR"
        env -i PATH="$BASE_PATH" HOME="$TMPDIR/home" FULL_INIT="$FULL_INIT" \
          TEMPLATE_PATH="$TEMPLATE_PATH" TARGET="$TARGET" TMPDIR="$TMPDIR" bash -c '
            set -euo pipefail
            source "$FULL_INIT"
            export TEMPLATE_PATH TARGET
            bash ${./../tests/firmware.bash}
          ' bash
        touch "$out"
      '';

  mkEimCheck =
    let
      eim = (builtins.head (builtins.attrValues envsByMajor)).eim;
    in
    pkgs.runCommand "esp-idf-eim-help" { nativeBuildInputs = [ eim ]; } ''
      eim --help >/dev/null
      touch "$out"
    '';

  prefetchTests =
    pkgs.runCommand "prefetch-version-tests"
      {
        nativeBuildInputs = [ pkgs.bash ];
        PREFETCH_VERSION_BIN = "${prefetchVersion}/bin/prefetch-version";
      }
      ''
        bash ${./../tests/prefetch-version.bash}
        touch "$out"
      '';
in
{
  prefetch-version = prefetchTests;
  eim-help = mkEimCheck;
}
// lib.listToAttrs (
  lib.concatMap (major: [
    {
      name = "v${major}-runtime";
      value = mkRuntimeCheck major;
    }
    {
      name = "v${major}-esp32-firmware";
      value = mkFirmwareCheck major "esp32";
    }
    {
      name = "v${major}-esp32c3-firmware";
      value = mkFirmwareCheck major "esp32c3";
    }
  ]) majors
)
