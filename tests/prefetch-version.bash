#!/usr/bin/env bash
set -euo pipefail

: "${PREFETCH_VERSION_BIN:?set PREFETCH_VERSION_BIN to the packaged helper}"

workspace_root="$(pwd -P)"
workspace_tools_checksum=""
workspace_constraints_checksum=""
if [ -f "$workspace_root/data/tools/v5.5.4.json" ]; then
  workspace_tools_checksum="$(cksum "$workspace_root/data/tools/v5.5.4.json")"
  workspace_constraints_checksum="$(cksum "$workspace_root/data/constraints/v5.5.4.txt")"
fi
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT
# The helper writes paths relative to its working directory, so every fixture
# runs below this temporary root and cannot touch repository snapshots.

write_valid_tools() {
  cat > "$1" <<'JSON'
{"tools":[{"name":"xtensa-esp-elf","install":"always","description":"test","info_url":"https://example.invalid/tool","versions":[{"name":"test","status":"recommended","any":{"url":"https://example.invalid/tool","sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}}]}]}
JSON
}

curl() {
  local output=""
  local url=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -o) output="$2"; shift 2 ;;
      -*) shift ;;
      *) url="$1"; shift ;;
    esac
  done

  case "${FAKE_CURL_MODE:-ok}" in
    tools)
      write_valid_tools "$output"
      ;;
    constraints)
      printf '%s\n' 'setuptools>=64' > "$output"
      ;;
    malformed-tools)
      if [[ "$url" == */tools/tools.json ]]; then
        printf '%s\n' '{}' > "$output"
      else
        printf '%s\n' 'setuptools>=64' > "$output"
      fi
      ;;
    malformed-json)
      if [[ "$url" == */tools/tools.json ]]; then
        printf '%s\n' '{"tools": [' > "$output"
      else
        printf '%s\n' 'setuptools>=64' > "$output"
      fi
      ;;
    malformed-tools-structure)
      if [[ "$url" == */tools/tools.json ]]; then
        printf '%s\n' '{"tools":[{"name":"xtensa-esp-elf","install":"always","description":"test","info_url":"https://example.invalid/tool","versions":[{"name":"test"}]}]}' > "$output"
      else
        printf '%s\n' 'setuptools>=64' > "$output"
      fi
      ;;
    malformed-constraints)
      if [[ "$url" == */tools/tools.json ]]; then
        write_valid_tools "$output"
      else
        printf '%s\n' '<html>not metadata</html>' > "$output"
      fi
      ;;
    fail-tools)
      return 22
      ;;
    fail-constraints)
      if [[ "$url" == */tools/tools.json ]]; then
        write_valid_tools "$output"
      else
        return 22
      fi
      ;;
    mixed-constraints)
      if [[ "$url" == */tools/tools.json ]]; then
        write_valid_tools "$output"
      else
        printf '%s\n' 'setuptools>=64' '<html>broken</html>' > "$output"
      fi
      ;;
    *)
      if [[ "$url" == */tools/tools.json ]]; then
        write_valid_tools "$output"
      else
        printf '%s\n' 'setuptools>=64' > "$output"
      fi
      ;;
  esac

  printf '%s\n' "$url" >> "$FAKE_CURL_LOG"
}

nix() {
  local mode="${FAKE_NIX_MODE:-ok}"
  printf '%s\n' "$*" >> "$FAKE_NIX_LOG"
  if [ "$mode" = "success" ]; then
    return 0
  fi
  if [ "$mode" = "fail" ]; then
    printf '%s\n' 'source prefetch failed' >&2
    return 1
  fi
  printf '%s\n' 'got: sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=' >&2
  if [ "$mode" = "bad-hash" ]; then
    printf '%s\n' 'got: sha256-invalid' >&2
  fi
  return 1
}

export -f write_valid_tools curl nix

run_helper() {
  local version="$1"
  local root="$2"
  (
    cd -- "$root" || exit 1
    test "$(pwd -P)" = "$(realpath "$root")"
    FAKE_CURL_LOG="$root/curl.log" FAKE_NIX_LOG="$root/nix.log" "$PREFETCH_VERSION_BIN" "$version" 2> "$root/error.log"
  )
}

new_repo() {
  local root="$1"
  mkdir -p "$root/data/tools" "$root/data/constraints"
}

assert_file() {
  [ -f "$1" ] || { echo "expected file: $1" >&2; return 1; }
}

assert_same() {
  cmp -s "$1" "$2" || { echo "files differ: $1 $2" >&2; return 1; }
}

# Stable releases keep the complete version in the GitHub tag and output names.
stable="$test_root/stable"
new_repo "$stable"
if ! run_helper 5.5.4 "$stable" > "$stable/output"; then
  cat "$stable/output" >&2
  cat "$stable/error.log" >&2
  exit 1
fi
assert_file "$stable/data/tools/v5.5.4.json"
assert_file "$stable/data/constraints/v5.5.4.txt"
grep -Fx 'https://raw.githubusercontent.com/espressif/esp-idf/v5.5.4/tools/tools.json' "$stable/curl.log"
grep -Fx 'https://dl.espressif.com/dl/esp-idf/espidf.constraints.v5.5.txt' "$stable/curl.log"
grep -Fq '"5.5.4"' "$stable/output"
grep -Fq 'v5.5.4' "$stable/nix.log"

# Prereleases use their full tag while constraints remain keyed by numeric major/minor.
prerelease="$test_root/prerelease"
new_repo "$prerelease"
if ! run_helper 6.0-rc1 "$prerelease" > "$prerelease/output"; then
  cat "$prerelease/output" >&2
  cat "$prerelease/error.log" >&2
  exit 1
fi
assert_file "$prerelease/data/tools/v6.0-rc1.json"
assert_file "$prerelease/data/constraints/v6.0-rc1.txt"
grep -Fx 'https://raw.githubusercontent.com/espressif/esp-idf/v6.0-rc1/tools/tools.json' "$prerelease/curl.log"
grep -Fx 'https://dl.espressif.com/dl/esp-idf/espidf.constraints.v6.0.txt' "$prerelease/curl.log"
grep -Fq 'v6.0-rc1' "$prerelease/nix.log"

# Invalid input is rejected before any network access or destination creation.
for version in nope 6 6..0 6.0.1.2 6.0/rc1 6.0\ rc1; do
  invalid="$test_root/invalid-${version//[^[:alnum:]]/_}"
  new_repo "$invalid"
  if run_helper "$version" "$invalid" > /dev/null 2>&1; then
    echo "invalid version unexpectedly accepted: $version" >&2
    exit 1
  fi
  [ ! -s "$invalid/curl.log" ] || { echo "invalid version made a request: $version" >&2; exit 1; }
done

failure_case() {
  local name="$1"
  local curl_mode="$2"
  local nix_mode="$3"
  local root="$test_root/$name"
  local old_tools="$root.old-tools"
  local old_constraints="$root.old-constraints"

  new_repo "$root"
  printf '%s\n' old-tools > "$root/data/tools/v6.0.2.json"
  printf '%s\n' old-constraints > "$root/data/constraints/v6.0.2.txt"
  cp "$root/data/tools/v6.0.2.json" "$old_tools"
  cp "$root/data/constraints/v6.0.2.txt" "$old_constraints"

  if FAKE_CURL_MODE="$curl_mode" FAKE_NIX_MODE="$nix_mode" run_helper 6.0.2 "$root" > /dev/null 2>&1; then
    echo "failure case unexpectedly succeeded: $name" >&2
    exit 1
  fi
  assert_same "$root/data/tools/v6.0.2.json" "$old_tools"
  assert_same "$root/data/constraints/v6.0.2.txt" "$old_constraints"
}

failure_case download-failure fail-constraints ok
failure_case first-download-failure fail-tools ok
failure_case malformed-tools malformed-tools ok
failure_case malformed-json malformed-json ok
failure_case malformed-tools-structure malformed-tools-structure ok
failure_case malformed-constraints malformed-constraints ok
failure_case mixed-constraints mixed-constraints ok
failure_case source-hash-failure ok fail
failure_case bad-source-hash ok bad-hash
failure_case unexpected-source-success ok success

test "$(pwd -P)" = "$workspace_root"
if [ -n "$workspace_tools_checksum" ]; then
  test "$(cksum "$workspace_root/data/tools/v5.5.4.json")" = "$workspace_tools_checksum"
  test "$(cksum "$workspace_root/data/constraints/v5.5.4.txt")" = "$workspace_constraints_checksum"
fi

echo "prefetch-version tests passed"
