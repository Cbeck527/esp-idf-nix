{ pkgs, system }:

let
  version = "0.10.5";

  sources = {
    x86_64-linux = {
      url = "https://github.com/espressif/idf-im-ui/releases/download/v${version}/eim-cli-linux-x64.zip";
      hash = "sha256-DnzBqyuAsbmokLZ+RhE6FS35UgCWPLSutErNYOJzJW4=";
    };
    aarch64-linux = {
      url = "https://github.com/espressif/idf-im-ui/releases/download/v${version}/eim-cli-linux-aarch64.zip";
      hash = "sha256-W7Octtd7RveKsaEcJpG/Ebiinp/V1N6O5yzvPL4IHpo=";
    };
    x86_64-darwin = {
      url = "https://github.com/espressif/idf-im-ui/releases/download/v${version}/eim-cli-macos-x64.zip";
      hash = "sha256-SwvMq/nrzKyEGjKUGmgPreUXGW9l2xgtMytFIbv8yZE=";
    };
    aarch64-darwin = {
      url = "https://github.com/espressif/idf-im-ui/releases/download/v${version}/eim-cli-macos-aarch64.zip";
      hash = "sha256-rpCTYKPJcwIKW2BzJzOF5/6CikKKXlgKHpTZawMluXE=";
    };
  };

  source =
    if builtins.hasAttr system sources then
      sources.${system}
    else
      throw "Unsupported system for eim: ${system}";
in
pkgs.stdenv.mkDerivation {
  pname = "eim";
  inherit version;

  src = pkgs.fetchurl {
    inherit (source) url hash;
  };

  nativeBuildInputs = [ pkgs.unzip ];
  sourceRoot = ".";
  dontBuild = true;

  installPhase = ''
    install -Dm755 eim $out/bin/eim
  '';

  meta = {
    description = "ESP-IDF Installation Manager CLI";
    homepage = "https://github.com/espressif/idf-im-ui";
    platforms = builtins.attrNames sources;
  };
}
