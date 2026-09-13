{
  pkgs,
  lib,
  espIdfVersion ? null,
  constraintsFile ? null,
}:

let
  py = pkgs.python3Packages;

  # These hooks are kept with the profile data so package definitions consume
  # one source of truth for metadata relaxations as well as pins.
  pythonRelaxDeps = {
    # nixpkgs currently provides cryptography 46.0.5, which is newer than the
    # upper bound in the ESP-IDF 5.5 metadata.
    esptool = [ "cryptography" ];

    # esp-coredump's upstream metadata is narrower than the esptool and
    # construct versions selected by the packaged toolchain.
    esp-coredump = [
      "esptool"
      "construct"
    ];
  };

  releaseLineFor =
    version:
    if builtins.match "^[0-9]+\\.[0-9]+(\\.[0-9]+)?$" version == null then
      throw "Invalid ESP-IDF version '${version}'. Use a numeric release such as 5.5.4 or 6.0.2."
    else
      lib.versions.majorMinor version;

  profiles = {
    # ESP-IDF pins Python tooling per release line, so 5.5.x and 6.0.x need
    # different package versions.
    "5.5" = {
      esp-idf-kconfig = {
        version = "2.5.3";
        url = "https://files.pythonhosted.org/packages/7b/fa/e2676f920db7f0be035d4feb2e074328656a438f4c1c93e660738b04bfd0/esp_idf_kconfig-2.5.3.tar.gz";
        sha256 = "1c5f543bd94bf99144b4f20e583877da72c3d6f39b89b28ae3d96c30bbe7c50c";
      };

      esptool = {
        version = "4.12.dev3";
        url = "https://files.pythonhosted.org/packages/fb/e3/16550412544581e57d5e154faf6c7482d10b4085efceee7ad6badc359eae/esptool-4.12.dev3.tar.gz";
        sha256 = "fade69a55f491f7c8c6a57d0213bd95e1cae468078b7c7fb491a913f8e80e9fa";
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
      };

      idf-component-manager = {
        version = "2.4.9";
        url = "https://files.pythonhosted.org/packages/32/07/9564de74e38436bf3e8a20cbfac6afbdd106a5b49cfafdc2462c2f11fbb3/idf_component_manager-2.4.9.tar.gz";
        sha256 = "6f3884cd9d23d643c2daaf20aff4b20cff005220016749d8638da6780f8e2eec";
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
        pythonRelaxDeps = [
          "click"
          "pydantic"
          "urllib3"
        ];
      };

      esp-idf-size = {
        version = "1.7.1";
        url = "https://files.pythonhosted.org/packages/f7/a0/c8b13d7b27daec1e88a8d6c5f8f3cf6f4eae795c70f19fb70c4bc37ce943/esp_idf_size-1.7.1.tar.gz";
        sha256 = "95a6d460a26e9330035aaf1e1c25ccf37160549756214320ccca8404d97dcc1b";
      };
    };

    "6.0" = {
      esp-idf-kconfig = {
        version = "3.7.0";
        url = "https://files.pythonhosted.org/packages/09/e4/c1149c2ea12304d92f8852893d7e116e7541b6cf56bd416f0ef65ad310ac/esp_idf_kconfig-3.7.0.tar.gz";
        sha256 = "57cc5d8b03741c1d6d9fb3eadac5c925527797b61207cda47b6e407e1376ff95";
      };

      esptool = {
        version = "5.3.dev2";
        url = "https://files.pythonhosted.org/packages/6b/71/3967bf956a2b568bcbac8b5034f81ec5cc7ccc2303358c2aae89d2d3ea08/esptool-5.3.dev2.tar.gz";
        sha256 = "104c717437a01a248993aa9fd1b61451591e95637f88c9a155efe8af4b7a5d97";
        dependencies = with py; [
          bitstring
          click
          cryptography
          intelhex
          pyserial
          pyyaml
          reedsolo
          rich-click
        ];
      };

      idf-component-manager = {
        version = "3.0.1";
        url = "https://files.pythonhosted.org/packages/b7/34/a4703e9bc2f1193d36e3090d7fbb55d04c3751d4ac72ca1588fcd562c4cb/idf_component_manager-3.0.1.tar.gz";
        sha256 = "76e4ce0d353d4c2f0c186257df852f78874f9b8d37f670e19789f34c0571ad7c";
        dependencies = with py; [
          click
          colorama
          jsonref
          psutil
          pydantic
          pydantic-core
          pydantic-settings
          pyparsing
          requests
          requests-file
          requests-toolbelt
          ruamel-yaml
          tqdm
          truststore
        ];
        pythonRelaxDeps = [
          "click"
          "pydantic"
          "urllib3"
        ];
      };

      esp-idf-size = {
        version = "2.1.0";
        url = "https://files.pythonhosted.org/packages/4e/68/2052f458ac58d86a80b4cfe71bbce9c99982f906e36d6f49be2bddb85fdb/esp_idf_size-2.1.0.tar.gz";
        sha256 = "c010472bd89e405aa340815fa7c24ebb4852718f9d576b5b749bea84f21c2051";
      };
    };
  };

  supportedReleaseLines = builtins.attrNames profiles;

  profileFor =
    version:
    let
      releaseLine = releaseLineFor version;
    in
    profiles.${releaseLine}
      or (throw "Unsupported ESP-IDF Python package profile ${releaseLine} for version ${version}");

  releaseLine = if espIdfVersion == null then null else releaseLineFor espIdfVersion;
  profile = if espIdfVersion == null then null else profileFor espIdfVersion;

  # Keep the upstream file immutable and make every relaxation explicit. The
  # checks stop a changed upstream file from silently losing a constraint.
  #
  # Each upstream bound is incompatible with a package already selected in the
  # Nix environment: cryptography 46.0.5 exceeds the v5.5 <45 cap, click 8.3.1
  # exceeds <8.2, pyparsing 3.3.2 exceeds <3.3, and the packaged
  # esp-idf-nvs-partition-gen 0.2.0 is newer than ~=0.1.9. Keep lower bounds
  # and only remove these stale upper bounds.
  effectiveConstraints =
    if constraintsFile == null then
      throw "python-profiles.nix requires constraintsFile when espIdfVersion is set"
    else
      pkgs.runCommand "espidf-constraints.v${releaseLine}" { } ''
        cp ${constraintsFile} "$out"
        for pattern in \
          '^cryptography>=2\.1\.4.*$' \
          '^click>=7\.0.*$' \
          '^pyparsing>=3\.1\.0.*$' \
          '^esp-idf-nvs-partition-gen~=0\.1\.9$'; do
          count=$(grep -Ec "$pattern" "$out")
          test "$count" -eq 1 || {
            echo "expected exactly one upstream constraint matching $pattern" >&2
            exit 1
          }
        done

        sed \
          -e 's/^cryptography>=2\.1\.4.*/cryptography>=2.1.4/' \
          -e 's/^click>=7\.0.*/click>=7.0/' \
          -e 's/^pyparsing>=3\.1\.0.*/pyparsing>=3.1.0/' \
          -e 's/^esp-idf-nvs-partition-gen~=.*/esp-idf-nvs-partition-gen>=0.1.9/' \
          "$out" > "$out.tmp"
        mv "$out.tmp" "$out"
      '';
in
{
  inherit
    releaseLineFor
    profileFor
    supportedReleaseLines
    pythonRelaxDeps
    releaseLine
    profile
    ;
  constraintsFile = effectiveConstraints;
}
