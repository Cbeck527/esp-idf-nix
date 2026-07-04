{ pkgs, nixpkgsPath }:

pkgs.writeShellApplication {
  name = "prefetch-version";

  runtimeInputs = [
    pkgs.coreutils
    pkgs.curl
    pkgs.gnused
    pkgs.nix
  ];

  text = ''
    set -euo pipefail

    if [ "$#" -ne 1 ]; then
      echo "usage: prefetch-version <esp-idf-version>" >&2
      exit 1
    fi

    version="$1"
    tag="v$version"
    major="$(printf '%s' "$version" | cut -d. -f1)"
    major_minor="$(printf '%s' "$version" | cut -d. -f1,2)"
    tools_json_url="https://raw.githubusercontent.com/espressif/esp-idf/$tag/tools/tools.json"
    constraints_url="https://dl.espressif.com/dl/esp-idf/espidf.constraints.v$major_minor.txt"
    tools_path="data/tools/$tag.json"
    constraints_path="data/constraints/$tag.txt"

    if [ ! -d data ]; then
      echo "run prefetch-version from the repository root (data/ not found)" >&2
      exit 1
    fi

    mkdir -p data/tools data/constraints
    curl -fsSL "$tools_json_url" -o "$tools_path"
    curl -fsSL "$constraints_url" -o "$constraints_path"

    tmpdir="$(mktemp -d)"
    trap 'rm -rf "$tmpdir"' EXIT

    set +e
    nix build --no-link --impure --expr "
      let
        pkgs = import ${nixpkgsPath} { system = builtins.currentSystem; };
      in
      pkgs.fetchFromGitHub {
        owner = \"espressif\";
        repo = \"esp-idf\";
        rev = \"$tag\";
        fetchSubmodules = true;
        hash = pkgs.lib.fakeHash;
      }
    " > /dev/null 2> "$tmpdir/source-hash.log"
    build_status="$?"
    set -e

    if [ "$build_status" -eq 0 ]; then
      echo "expected fetchFromGitHub prefetch to fail with a fake hash" >&2
      exit 1
    fi

    src_hash="$(
      sed -n 's/^[[:space:]]*got:[[:space:]]*//p' "$tmpdir/source-hash.log" | tail -n1
    )"

    if [ -z "$src_hash" ]; then
      echo "failed to determine ESP-IDF source hash" >&2
      cat "$tmpdir/source-hash.log" >&2
      exit 1
    fi

    cat <<EOF
    "$version" = {
      srcHash = "$src_hash";
      constraintsPath = ./constraints/$tag.txt;
      toolsJsonPath = ./tools/$tag.json;
    };

    # Wrote $tools_path and $constraints_path
    # If this should become the v$major alias, update latestByMajor."$major" = "$version";
    EOF
  '';
}
