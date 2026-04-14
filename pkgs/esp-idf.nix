# pkgs/esp-idf.nix
#
# Packages the ESP-IDF framework source (with all submodules) into the
# Nix store. This gives users a reproducible, pre-fetched ESP-IDF that
# works with `idf.py` out of the box.
#
# ── Key challenge: git in the Nix store ──
# ESP-IDF's build system calls `git describe --tags` to determine the
# IDF version (IDF_VER). Since Nix store paths don't have a .git
# directory, we create a minimal fake one during the build phase so
# `git describe` returns the correct version string.
#
# The source and version are passed in from flake.nix so they can be
# overridden via the mkEspIdfEnv function.
#
# Called from flake.nix with:
#   esp-idf = import ./pkgs/esp-idf.nix {
#     inherit pkgs lib version idfSrc constraintsHash;
#   };

{
  pkgs,
  lib,
  version,
  idfSrc,
  constraintsHash,
}:

let
  versionMajorMinor = lib.versions.majorMinor version;

  # ── Constraints file ──
  # idf.py checks for this file to verify the environment is set up.
  # Normally created by install.sh, but we manage Python via Nix.
  # We fetch it from Espressif's CDN and include it in our package.
  constraintsFile = pkgs.fetchurl {
    url = "https://dl.espressif.com/dl/esp-idf/espidf.constraints.v${versionMajorMinor}.txt";
    hash = constraintsHash;
  };
in
pkgs.stdenv.mkDerivation {
  pname = "esp-idf";
  inherit version;

  # Source is fetched in flake.nix (fetchFromGitHub with fetchSubmodules)
  # and passed in so that tools.json can also be read from it at eval time.
  src = idfSrc;

  nativeBuildInputs = [ pkgs.git ];

  dontBuild = true;
  dontFixup = true;

  installPhase = ''
    # Copy the full source tree to the output
    cp -r . $out

    # ── Create a fake git repo ──
    # ESP-IDF's CMake build calls `git describe --tags --dirty` to set
    # IDF_VER. Without a .git directory, this fails. We create a
    # minimal git repo with just enough state for `git describe` to
    # return the correct version.
    cd $out
    export HOME=$TMPDIR
    git init
    git config user.name "nix"
    git config user.email "nix@localhost"
    git commit --allow-empty -m "v${version}"
    git tag "v${version}"

    # ── Relax version constraints in requirements.core.txt ──
    # The upstream constraints are conservative upper bounds. Our
    # nixpkgs versions are slightly newer but API-compatible.
    sed -i \
      -e 's/cryptography>=2.1.4,<45/cryptography>=2.1.4/' \
      -e 's/click>=7.0,<8.2/click>=7.0/' \
      -e 's/pyparsing>=3.1.0,<3.3/pyparsing>=3.1.0/' \
      -e 's/esp-idf-nvs-partition-gen~=0.1.9/esp-idf-nvs-partition-gen>=0.1.9/' \
      $out/tools/requirements/requirements.core.txt

    # ── IDF tools path ──
    # idf.py checks $IDF_TOOLS_PATH for a constraints file to verify
    # the environment is set up. We place it inside the package so
    # the full devShell can point IDF_TOOLS_PATH here.
    #
    # We relax a few upper bounds that our nixpkgs versions exceed.
    # These are conservative constraints, not actual incompatibilities:
    #   click <8.2    -> we have 8.3 (API compatible)
    #   cryptography <45 -> we have 46 (API compatible)
    #   pyparsing <3.3   -> we have 3.3.2 (minor bump)
    mkdir -p $out/tools-path
    sed \
      -e 's/,<45//' \
      -e 's/,<8.2//' \
      -e 's/,<3.3//' \
      -e 's/~=0.1.9/>=0.1.9/' \
      ${constraintsFile} > $out/tools-path/espidf.constraints.v${versionMajorMinor}.txt
  '';

  passthru = {
    inherit version;
    toolsPath = placeholder "out" + "/tools-path";
  };

  meta = {
    description = "Espressif IoT Development Framework";
    homepage = "https://github.com/espressif/esp-idf";
    license = lib.licenses.asl20;
  };
}
