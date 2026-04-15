#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
eim_file="$repo_root/pkgs/eim.nix"

version="$(
  sed -nE 's/^[[:space:]]*version = "([^"]+)";$/\1/p' "$eim_file"
)"

if [ -z "$version" ]; then
  echo "error: failed to read the EIM version from $eim_file" >&2
  exit 1
fi

url_for_system() {
  case "$1" in
    x86_64-linux)
      printf '%s\n' "https://github.com/espressif/idf-im-ui/releases/download/v${version}/eim-cli-linux-x64.zip"
      ;;
    aarch64-linux)
      printf '%s\n' "https://github.com/espressif/idf-im-ui/releases/download/v${version}/eim-cli-linux-aarch64.zip"
      ;;
    x86_64-darwin)
      printf '%s\n' "https://github.com/espressif/idf-im-ui/releases/download/v${version}/eim-cli-macos-x64.zip"
      ;;
    aarch64-darwin)
      printf '%s\n' "https://github.com/espressif/idf-im-ui/releases/download/v${version}/eim-cli-macos-aarch64.zip"
      ;;
    *)
      echo "error: unsupported system: $1" >&2
      exit 1
      ;;
  esac
}

prefetch_hash() {
  local url="$1"
  local json
  local hash

  json="$(nix store prefetch-file --json "$url")"
  hash="$(
    printf '%s' "$json" | sed -nE 's/.*"hash"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p'
  )"

  if [ -z "$hash" ]; then
    echo "error: failed to parse hash for $url" >&2
    exit 1
  fi

  printf '%s\n' "$hash"
}

systems=(
  x86_64-linux
  aarch64-linux
  x86_64-darwin
  aarch64-darwin
)

for system in "${systems[@]}"; do
  hash="$(prefetch_hash "$(url_for_system "$system")")"
  printf '%s\t%s\n' "$system" "$hash"
done
