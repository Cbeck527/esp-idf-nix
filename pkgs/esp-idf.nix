{
  pkgs,
  lib,
  version,
  idfSrc,
  constraintsHash,
}:

let
  versionMajorMinor = lib.versions.majorMinor version;

  constraintsFile = pkgs.fetchurl {
    url = "https://dl.espressif.com/dl/esp-idf/espidf.constraints.v${versionMajorMinor}.txt";
    hash = constraintsHash;
  };
in
pkgs.stdenv.mkDerivation {
  pname = "esp-idf";
  inherit version;

  src = idfSrc;

  nativeBuildInputs = [ pkgs.git ];

  dontBuild = true;
  dontFixup = true;

  installPhase = ''
    cp -r . $out

    # ESP-IDF derives IDF_VER from git metadata, so the store copy needs a tiny repo.
    cd $out
    export HOME=$TMPDIR
    export GIT_AUTHOR_NAME="nix"
    export GIT_AUTHOR_EMAIL="nix@localhost"
    export GIT_AUTHOR_DATE="1970-01-01T00:00:00Z"
    export GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME"
    export GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL"
    export GIT_COMMITTER_DATE="$GIT_AUTHOR_DATE"
    git -c init.defaultBranch=main init
    git config user.name "nix"
    git config user.email "nix@localhost"
    git commit --allow-empty -m "v${version}"
    git tag "v${version}"

    sed -i \
      -e 's/cryptography>=2.1.4,<45/cryptography>=2.1.4/' \
      -e 's/click>=7.0,<8.2/click>=7.0/' \
      -e 's/pyparsing>=3.1.0,<3.3/pyparsing>=3.1.0/' \
      -e 's/esp-idf-nvs-partition-gen~=0.1.9/esp-idf-nvs-partition-gen>=0.1.9/' \
      $out/tools/requirements/requirements.core.txt

    # Keep the constraints file inside the package so `idf.py` sees a configured tools path.
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
