{ pkgs, lib }:

let
  py = pkgs.python3Packages;
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
    version = "2.5.3";
    pyproject = true;

    src = pkgs.fetchurl {
      url = "https://files.pythonhosted.org/packages/7b/fa/e2676f920db7f0be035d4feb2e074328656a438f4c1c93e660738b04bfd0/esp_idf_kconfig-2.5.3.tar.gz";
      sha256 = "1c5f543bd94bf99144b4f20e583877da72c3d6f39b89b28ae3d96c30bbe7c50c";
    };

    build-system = [ py.setuptools ];

    dependencies = [
      py.rich
      py.pyparsing
    ];

    doCheck = false;

    meta.description = "ESP-IDF Kconfig tooling (menuconfig)";
  };

  esptool = py.buildPythonPackage {
    pname = "esptool";
    version = "4.8.1";
    pyproject = true;

    src = pkgs.fetchurl {
      url = "https://files.pythonhosted.org/packages/5c/6b/3ce9bb7f36bdef3d6ae71646a1d3b7d59826a478f3ed8a783a93a2f8f537/esptool-4.8.1.tar.gz";
      sha256 = "dc4ef26b659e1a8dcb019147c0ea6d94980b34de99fbe09121c7941c8b254531";
    };

    build-system = [ py.setuptools ];

    dependencies = with py; [
      bitstring
      cryptography
      ecdsa
      pyserial
      reedsolo
      pyyaml
      intelhex
      argcomplete
    ];

    # Relax esptool's metadata so it accepts the newer nixpkgs cryptography build.
    nativeBuildInputs = [ py.pythonRelaxDepsHook ];
    pythonRelaxDeps = [
      "cryptography"
    ];

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
    pythonRelaxDeps = [
      "esptool"
      "construct"
    ];

    doCheck = false;

    meta.description = "ESP core dump analysis tool";
  };

  esp-idf-monitor = py.buildPythonPackage {
    pname = "esp-idf-monitor";
    version = "1.9.0";
    pyproject = true;

    src = pkgs.fetchurl {
      url = "https://files.pythonhosted.org/packages/7c/86/64a8984759506fbbbfce14ec981ec736420aeb79ffc964166a507e3be065/esp_idf_monitor-1.9.0.tar.gz";
      sha256 = "0c38da0c3d383d4b6305863b8df8ea6e09303ad5a6d5ba92ce71b31f1cf700ce";
    };

    build-system = [ py.setuptools ];

    dependencies = [
      py.pyserial
      py.pyelftools
      esp-coredump
      esp-idf-panic-decoder
    ];

    nativeBuildInputs = [ py.pythonRelaxDepsHook ];
    pythonRelaxDeps = [
      "esp-coredump"
      "esp-idf-panic-decoder"
    ];

    doCheck = false;

    meta.description = "ESP-IDF serial monitor with panic decoding";
  };

  idf-component-manager = py.buildPythonPackage {
    pname = "idf-component-manager";
    version = "2.4.9";
    pyproject = true;

    src = pkgs.fetchurl {
      url = "https://files.pythonhosted.org/packages/32/07/9564de74e38436bf3e8a20cbfac6afbdd106a5b49cfafdc2462c2f11fbb3/idf_component_manager-2.4.9.tar.gz";
      sha256 = "6f3884cd9d23d643c2daaf20aff4b20cff005220016749d8638da6780f8e2eec";
    };

    build-system = [ py.setuptools ];

    dependencies = with py; [
      cachecontrol
      click
      colorama
      jsonref
      packaging
      psutil
      pydantic
      pydantic-settings
      pyparsing
      pyyaml
      requests
      requests-file
      requests-toolbelt
      ruamel-yaml
      schema
      tqdm
      truststore
    ];

    nativeBuildInputs = [ py.pythonRelaxDepsHook ];
    pythonRelaxDeps = [
      "click"
      "pydantic"
      "urllib3"
    ];

    doCheck = false;

    meta.description = "ESP-IDF component dependency manager";
  };

  esp-idf-size = py.buildPythonPackage {
    pname = "esp-idf-size";
    version = "1.7.1";
    pyproject = true;

    src = pkgs.fetchurl {
      url = "https://files.pythonhosted.org/packages/f7/a0/c8b13d7b27daec1e88a8d6c5f8f3cf6f4eae795c70f19fb70c4bc37ce943/esp_idf_size-1.7.1.tar.gz";
      sha256 = "95a6d460a26e9330035aaf1e1c25ccf37160549756214320ccca8404d97dcc1b";
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
  inherit
    pyclang
    esp-idf-panic-decoder
    esp-idf-nvs-partition-gen
    esp-idf-kconfig
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
    ps.freertos-gdb
  ]);
}
