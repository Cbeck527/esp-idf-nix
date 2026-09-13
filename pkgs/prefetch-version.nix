{ pkgs, nixpkgsPath }:

pkgs.writeShellApplication {
  name = "prefetch-version";

  runtimeInputs = [
    pkgs.coreutils
    pkgs.curl
    pkgs.gnused
    pkgs.jq
    pkgs.nix
    (pkgs.python3.withPackages (ps: [ ps.packaging ]))
  ];

  text = ''
    set -euo pipefail

    if [ "$#" -ne 1 ]; then
      echo "usage: prefetch-version <esp-idf-version>" >&2
      exit 1
    fi

    version="$1"
    if [[ ! "$version" =~ ^([0-9]+)\.([0-9]+)(\.[0-9]+)?([+-][0-9A-Za-z.-]+)?$ ]]; then
      echo "invalid ESP-IDF version '$version' (expected N.N, N.N.N, or a prerelease tag)" >&2
      exit 1
    fi

    tag="v$version"
    major="''${BASH_REMATCH[1]}"
    major_minor="''${BASH_REMATCH[1]}.''${BASH_REMATCH[2]}"
    tools_json_url="https://raw.githubusercontent.com/espressif/esp-idf/$tag/tools/tools.json"
    constraints_url="https://dl.espressif.com/dl/esp-idf/espidf.constraints.v$major_minor.txt"
    tools_path="data/tools/$tag.json"
    constraints_path="data/constraints/$tag.txt"

    if [ ! -d data ]; then
      echo "run prefetch-version from the repository root (data/ not found)" >&2
      exit 1
    fi

    tmpdir="$(mktemp -d)"
    trap 'rm -rf "$tmpdir"' EXIT
    tools_tmp="$tmpdir/$tag.json"
    constraints_tmp="$tmpdir/$tag.txt"

    curl -fsSL "$tools_json_url" -o "$tools_tmp"
    curl -fsSL "$constraints_url" -o "$constraints_tmp"

    if ! jq -e '
      type == "object" and
      (.tools | type == "array" and length > 0) and
      all(.tools[];
        type == "object" and
        (.install | type == "string" and length > 0)
      ) and
      any(.tools[]; .install == "always") and
      all(.tools[] | select(.install == "always");
        (.name | (type == "string" and length > 0)) and
        (.description | (type == "string" and length > 0)) and
        (.info_url | (type == "string" and length > 0)) and
        (.versions | (type == "array" and length > 0)) and
        all(.versions[];
          type == "object" and
          (.name | (type == "string" and length > 0)) and
          (.status | (type == "string" and length > 0)) and
          any(to_entries[];
            (.key == "any" or .key == "linux-amd64" or .key == "linux-arm64" or .key == "macos-arm64") and
            (.value | type == "object" and
              (.url | type == "string" and length > 0) and
              (.sha256 | test("^[0-9a-fA-F]{64}$"))))
        )
      )
    ' "$tools_tmp" >/dev/null; then
      echo "downloaded tools metadata is not a valid ESP-IDF tools.json" >&2
      exit 1
    fi

    if ! python - "$constraints_tmp" <<'PY'
    from pathlib import Path
    from packaging.requirements import Requirement
    import sys

    substantive = 0
    for raw_line in Path(sys.argv[1]).read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if line == "--only-binary" or line.startswith("--only-binary "):
            continue
        try:
            Requirement(line.split(" #", 1)[0].strip())
        except Exception as error:
            raise SystemExit(f"invalid Python requirement {line!r}: {error}")
        substantive += 1

    if substantive == 0:
        raise SystemExit("constraints file contains no Python requirements")
    PY
    then
      echo "downloaded constraints metadata is empty or malformed" >&2
      exit 1
    fi

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
    if [[ ! "$src_hash" =~ ^sha256-[A-Za-z0-9+/]{43}=$ ]]; then
      echo "source prefetch returned an invalid SRI sha256 hash: $src_hash" >&2
      exit 1
    fi

    mkdir -p data/tools data/constraints
    mv "$tools_tmp" "$tools_path"
    mv "$constraints_tmp" "$constraints_path"

    cat <<EOF
    "$version" = {
      srcHash = "$src_hash";
      constraintsPath = ./constraints/$tag.txt;
      toolsJsonPath = ./tools/$tag.json;
    };

    # Wrote $tools_path and $constraints_path after validating both downloads and the source hash.
    # If this should become the v$major alias, update latestByMajor."$major" = "$version";
    EOF
  '';
}
