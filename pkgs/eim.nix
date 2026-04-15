{
  pkgs,
  system,
}:

let
  version = "0.11.1";

  sources = {
    x86_64-linux = {
      url = "https://github.com/espressif/idf-im-ui/releases/download/v${version}/eim-cli-linux-x64.zip";
      hash = "sha256-1BIydK0f/k4s1V93ObUW9NvvCmzs9koaAUr0p2bgnzk=";
    };
    aarch64-linux = {
      url = "https://github.com/espressif/idf-im-ui/releases/download/v${version}/eim-cli-linux-aarch64.zip";
      hash = "sha256-jhSyvxOGXh39UdTELFz4YP9MEWWCJbU/3fr5YodyOfo=";
    };
    x86_64-darwin = {
      url = "https://github.com/espressif/idf-im-ui/releases/download/v${version}/eim-cli-macos-x64.zip";
      hash = "sha256-GNGIZrsIRKv4rYbiuIUx8KbZ//BHPzyxRoemX2ro3gs=";
    };
    aarch64-darwin = {
      url = "https://github.com/espressif/idf-im-ui/releases/download/v${version}/eim-cli-macos-aarch64.zip";
      hash = "sha256-y8ea/tKW0+M5PRd9afA48dLrIDQptuJW2fTm6dzwoxw=";
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
    name = "eim-${version}-${system}.zip";
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
