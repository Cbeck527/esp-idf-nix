{
  pkgs,
  lib,
  espIdfVersion,
  constraintsFile,
}:

let
  py = pkgs.python3Packages;
  pythonProfile = import ./python-profiles.nix {
    inherit
      pkgs
      lib
      espIdfVersion
      constraintsFile
      ;
  };
  profile = pythonProfile.profile;

  pyclang = py.buildPythonPackage {
    pname = "pyclang";
    version = "0.6.3";
    pyproject = true;

    src = pkgs.fetchurl {
      url = "https://files.pythonhosted.org/packages/84/5a/246d89413dfb3fbd24185e0baf2697be3eb6ef5ce7f0dc22f32fcc4ce47b/pyclang-0.6.3.tar.gz";
      sha256 = "0b1151c1986219f41cb91a5773241095e8d2283feaa8f947c989c6584fc4d56a";
    };

    build-system = [ py.setuptools ];

    dependencies = [ ];

    doCheck = false;

    meta.description = "Python clang-tidy runner";
  };

  esp-idf-panic-decoder = py.buildPythonPackage {
    pname = "esp-idf-panic-decoder";
    version = "1.4.2";
    pyproject = true;

    src = pkgs.fetchurl {
      url = "https://files.pythonhosted.org/packages/6f/81/d871e711cca394b54d201d27c1429c0a155c01138f4a33be14b335d61b3a/esp_idf_panic_decoder-1.4.2.tar.gz";
      sha256 = "c239369542127a2a71c3b08320e4504f12920b64005b472362a33ec24064f7f5";
    };

    build-system = [ py.setuptools ];

    dependencies = [ py.pyelftools ];

    doCheck = false;

    meta.description = "ESP-IDF panic backtrace decoder";
  };

  esp-idf-nvs-partition-gen = py.buildPythonPackage {
    pname = "esp-idf-nvs-partition-gen";
    version = "0.2.0";
    pyproject = true;

    src = pkgs.fetchurl {
      url = "https://files.pythonhosted.org/packages/9b/cc/c463d1a1f81eecbb352d722a5995e6e14d5885cc33fe61265538acb16ade/esp_idf_nvs_partition_gen-0.2.0.tar.gz";
      sha256 = "d1f23ce9876c0469e507b3499001266d0d17538158151a2612cc70b80706dce0";
    };

    build-system = [ py.setuptools ];

    dependencies = [ py.cryptography ];

    doCheck = false;

    meta.description = "ESP-IDF NVS partition generation tool";
  };

  esp-idf-kconfig = py.buildPythonPackage {
    pname = "esp-idf-kconfig";
    version = profile.esp-idf-kconfig.version;
    pyproject = true;

    src = pkgs.fetchurl {
      inherit (profile.esp-idf-kconfig) url sha256;
    };

    build-system = [ py.setuptools ];

    dependencies = [
      py.rich
      py.pyparsing
    ];

    doCheck = false;

    meta.description = "ESP-IDF Kconfig tooling (menuconfig)";
  };

  esp-idf-diag = py.buildPythonPackage {
    pname = "esp-idf-diag";
    version = "0.2.0";
    pyproject = true;

    src = pkgs.fetchurl {
      url = "https://files.pythonhosted.org/packages/5d/e8/ebb81a1a297dfc2c1d94dce2a412b1e956049baed8ddcaf0d61cc26a2e7a/esp_idf_diag-0.2.0.tar.gz";
      sha256 = "83affa9922e7ab9e9e11683f3507356f590385f735a43532442d2d9301a4e8a0";
    };

    build-system = [ py.setuptools ];

    dependencies = with py; [
      pyyaml
      rich
    ];

    doCheck = false;

    meta.description = "ESP-IDF diagnostics and bug report tool";
  };

  tree-sitter-c = py.buildPythonPackage {
    pname = "tree-sitter-c";
    version = "0.24.1";
    pyproject = true;

    src = pkgs.fetchurl {
      url = "https://files.pythonhosted.org/packages/f1/f5/ba8cd08d717277551ade8537d3aa2a94b907c6c6e0fbcf4e4d8b1c747fa3/tree_sitter_c-0.24.1.tar.gz";
      sha256 = "7d2d0cda0b8dda428c81440c1e94367f9f13548eedca3f49768bde66b1422ad6";
    };

    build-system = [
      py.setuptools
      py.wheel
    ];

    dependencies = [ py.tree-sitter ];

    doCheck = false;

    meta.description = "C grammar for tree-sitter";
  };

  esptool = py.buildPythonPackage {
    pname = "esptool";
    version = profile.esptool.version;
    pyproject = true;

    src = pkgs.fetchurl {
      inherit (profile.esptool) url sha256;
    };

    build-system = [ py.setuptools ];

    dependencies = profile.esptool.dependencies;

    # Relax esptool's metadata so it accepts the newer nixpkgs cryptography build.
    nativeBuildInputs = [ py.pythonRelaxDepsHook ];
    pythonRelaxDeps = pythonProfile.pythonRelaxDeps.esptool;

    # esptool 5 ships deprecated bin/*.py launchers whose names shadow the
    # real modules after Nix wraps the console scripts. esptool 4 still uses
    # those .py commands, so keep them for the 5.5 profile.
    preFixup = lib.optionalString (lib.versions.major profile.esptool.version == "5") ''
      rm -f "$out"/bin/*.py
    '';

    doCheck = false;

    meta.description = "ESP chip serial flasher and provisioning utility";
  };

  esp-coredump = py.buildPythonPackage {
    pname = "esp-coredump";
    version = "1.15.0";
    pyproject = true;

    src = pkgs.fetchurl {
      url = "https://files.pythonhosted.org/packages/e2/4e/4ba12832cceda0ca8203f62d7c50b224c47ead4f50da0d48c4a421e52ac6/esp_coredump-1.15.0.tar.gz";
      sha256 = "5ffa4056607dacc6d514bde80d36ada372931a28b203e9f5b2e5703a6eea02ce";
    };

    build-system = [ py.setuptools ];

    dependencies = [
      py.construct
      py.pygdbmi
      esptool
    ];

    nativeBuildInputs = [ py.pythonRelaxDepsHook ];
    pythonRelaxDeps = pythonProfile.pythonRelaxDeps.esp-coredump;

    doCheck = false;

    meta.description = "ESP core dump analysis tool";
  };

  esp-pylib = py.buildPythonPackage {
    pname = "esp-pylib";
    version = "1.1.1";
    pyproject = true;

    src = pkgs.fetchurl {
      url = "https://files.pythonhosted.org/packages/86/9b/28b2f779bbd3d0379c563200dc81b15e2134bd6980d8a4fa1e26a8ef24d3/esp_pylib-1.1.1.tar.gz";
      sha256 = "4538b493d621727c8925cec7b065d6136e9afac9952ea56d61377b8628aacb4b";
    };

    build-system = [
      py.setuptools
      py.wheel
    ];

    dependencies = with py; [
      rich
      rich-click
      click
      pyserial
    ];

    doCheck = false;
    pythonImportsCheck = [ "esp_pylib" ];

    meta.description = "Shared Python utilities for Espressif tools";
  };

  esp-idf-monitor = py.buildPythonPackage {
    pname = "esp-idf-monitor";
    version = "1.10.0";
    pyproject = true;

    src = pkgs.fetchurl {
      url = "https://files.pythonhosted.org/packages/07/f6/6f97755905260363abfc07c2fa9139f690c078d2e8b2d23255ade7898c82/esp_idf_monitor-1.10.0.tar.gz";
      sha256 = "7adb6927afdaaa8546fb4b8eed7a6d20cca9b0aa80cfa5839d80171b8ed790f5";
    };

    build-system = [ py.setuptools ];

    dependencies = [
      py.pyserial
      py.pyelftools
      py.rich
      py.rich-click
      esp-coredump
      esp-idf-panic-decoder
      esp-pylib
    ];

    doCheck = false;
    pythonImportsCheck = [ "esp_idf_monitor" ];

    meta.description = "ESP-IDF serial monitor with panic decoding";
  };

  idf-component-manager = py.buildPythonPackage {
    pname = "idf-component-manager";
    version = profile.idf-component-manager.version;
    pyproject = true;

    src = pkgs.fetchurl {
      inherit (profile.idf-component-manager) url sha256;
    };

    build-system = [ py.setuptools ];

    dependencies = profile.idf-component-manager.dependencies;

    nativeBuildInputs = [ py.pythonRelaxDepsHook ];
    pythonRelaxDeps = profile.idf-component-manager.pythonRelaxDeps;

    doCheck = false;

    meta.description = "ESP-IDF component dependency manager";
  };

  esp-idf-size = py.buildPythonPackage {
    pname = "esp-idf-size";
    version = profile.esp-idf-size.version;
    pyproject = true;

    src = pkgs.fetchurl {
      inherit (profile.esp-idf-size) url sha256;
    };

    build-system = [ py.setuptools ];

    dependencies = with py; [
      pyyaml
      rich
    ];

    doCheck = false;

    meta.description = "ESP-IDF binary size analysis tool";
  };

in
{
  inherit (pythonProfile)
    releaseLineFor
    profileFor
    supportedReleaseLines
    ;

  releaseLine = pythonProfile.releaseLine;
  constraintsFile = pythonProfile.constraintsFile;

  inherit
    pyclang
    esp-idf-panic-decoder
    esp-idf-nvs-partition-gen
    esp-idf-kconfig
    esp-idf-diag
    tree-sitter-c
    esptool
    esp-coredump
    esp-idf-monitor
    idf-component-manager
    esp-idf-size
    ;

  # Keep one Python environment aligned with the packaged IDF toolchain.
  pythonEnv = pkgs.python3.withPackages (ps: [
    pyclang
    esp-idf-panic-decoder
    esp-idf-nvs-partition-gen
    esp-idf-kconfig
    esp-idf-diag
    tree-sitter-c
    esptool
    esp-coredump
    esp-idf-monitor
    idf-component-manager
    esp-idf-size

    ps.click
    ps.pyserial
    ps.cryptography
    ps.pyparsing
    ps.pyelftools
    ps.construct
    ps.rich
    ps.psutil
    ps.setuptools
    ps.packaging
    ps.pyyaml
    ps.tree-sitter
    ps.freertos-gdb
  ]);
}
