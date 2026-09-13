#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

: "${ESP_IDF_MAJOR:?set ESP_IDF_MAJOR}"
: "${FULL_INIT:?set FULL_INIT}"
: "${TOOLS_INIT:?set TOOLS_INIT}"
: "${V5_FULL_INIT:?set V5_FULL_INIT}"
: "${V6_FULL_INIT:?set V6_FULL_INIT}"
: "${IDF_PATH:?set IDF_PATH}"
: "${IDF_PYTHON_ENV_PATH:?set IDF_PYTHON_ENV_PATH}"
: "${ESP_IDF_CONSTRAINTS:?set ESP_IDF_CONSTRAINTS}"
: "${ESP_IDF_PYTHON_VERSION:?set ESP_IDF_PYTHON_VERSION}"
: "${ESP_IDF_ESPTOOL_VERSION:?set ESP_IDF_ESPTOOL_VERSION}"
: "${ESP_IDF_VERSION_EXPECTED:?set ESP_IDF_VERSION_EXPECTED}"
: "${BASE_PATH:?set BASE_PATH}"

run_full_commands() {
  env -i PATH="$BASE_PATH" HOME="$TMPDIR/full-home" \
    FULL_INIT="$FULL_INIT" IDF_PATH_EXPECTED="$IDF_PATH" \
    IDF_PYTHON_ENV_PATH_EXPECTED="$IDF_PYTHON_ENV_PATH" \
    ESP_IDF_CONSTRAINTS="$ESP_IDF_CONSTRAINTS" \
    ESP_IDF_PYTHON_VERSION="$ESP_IDF_PYTHON_VERSION" \
    ESP_IDF_ESPTOOL_VERSION="$ESP_IDF_ESPTOOL_VERSION" \
    ESP_IDF_MAJOR="$ESP_IDF_MAJOR" bash -c '
      set -euo pipefail
      source "$FULL_INIT"
      test "$IDF_PATH" = "$IDF_PATH_EXPECTED"
      test "$IDF_PYTHON_ENV_PATH" = "$IDF_PYTHON_ENV_PATH_EXPECTED"
      test "$IDF_PYTHON_CHECK_CONSTRAINTS" = no
      test "$IDF_TOOLS_PATH" = "$HOME/.espressif"
      test ! -e "$HOME/.espressif/python_env"
      python "$IDF_PATH/tools/check_python_dependencies.py" \
        -r "$IDF_PATH/tools/requirements/requirements.core.txt" \
        -c "$ESP_IDF_CONSTRAINTS"

      if [ "$ESP_IDF_MAJOR" = 5 ]; then
        esptool_cmd=esptool.py; espsecure_cmd=espsecure.py
        espefuse_cmd=espefuse.py; rfc2217_cmd=esp_rfc2217_server.py
      else
        esptool_cmd=esptool; espsecure_cmd=espsecure
        espefuse_cmd=espefuse; rfc2217_cmd=esp_rfc2217_server
      fi
      "$esptool_cmd" --help >/dev/null
      "$espsecure_cmd" --help >/dev/null
      "$espefuse_cmd" --help >/dev/null
      "$rfc2217_cmd" --help >/dev/null
      idf-monitor --help >/dev/null
      esp-coredump --help >/dev/null
      esp-idf-diag --help >/dev/null
      compote --help >/dev/null

      gdb_home="$HOME/gdb"
      mkdir -p "$gdb_home"
      python_assert="import gdb, freertos_gdb, esptool, sys; assert sys.version.startswith(\"${ESP_IDF_PYTHON_VERSION}.\"); assert esptool.__version__ == \"${ESP_IDF_ESPTOOL_VERSION}\""
      for gdb in xtensa-esp32-elf-gdb xtensa-esp32s2-elf-gdb xtensa-esp32s3-elf-gdb riscv32-esp-elf-gdb; do
        env -i HOME="$gdb_home" PATH="$PATH" "$gdb" --batch --nx --quiet -ex "python $python_assert"
      done
    ' bash
}

run_tools_state() {
  local tools_home="$TMPDIR/tools-home"
  local tools_path="$TMPDIR/tools-state"
  local caller_sdk="$TMPDIR/caller-sdk"
  mkdir -p "$tools_home" "$tools_path"
  ln -s "$IDF_PATH" "$caller_sdk"
  env -i PATH="$BASE_PATH" HOME="$tools_home" IDF_PATH="$caller_sdk" \
    IDF_TOOLS_PATH="$tools_path" TOOLS_PATH_EXPECTED="$tools_path" ESP_IDF_VERSION=bogus \
    TOOLS_INIT="$TOOLS_INIT" IDF_PATH_EXPECTED="$caller_sdk" \
    IDF_PYTHON_ENV_PATH_EXPECTED="$IDF_PYTHON_ENV_PATH" \
    ESP_IDF_CONSTRAINTS="$ESP_IDF_CONSTRAINTS" \
    ESP_IDF_VERSION_EXPECTED="$ESP_IDF_VERSION_EXPECTED" bash -c '
      set -euo pipefail
      source "$TOOLS_INIT"
      test "$IDF_PATH" = "$IDF_PATH_EXPECTED"
      test "$IDF_TOOLS_PATH" = "$TOOLS_PATH_EXPECTED"
      test "$IDF_PYTHON_ENV_PATH" = "$IDF_PYTHON_ENV_PATH_EXPECTED"
      test "$IDF_PYTHON_CHECK_CONSTRAINTS" = no
      test "$ESP_IDF_VERSION" = "$ESP_IDF_VERSION_EXPECTED"
      test ! -e "$HOME/.espressif/python_env"
      test ! -e "$IDF_TOOLS_PATH/python_env"
      python "$IDF_PATH/tools/check_python_dependencies.py" \
        -r "$IDF_PATH/tools/requirements/requirements.core.txt" \
        -c "$ESP_IDF_CONSTRAINTS"
      python "$IDF_PATH/tools/idf.py" --help >/dev/null
    ' bash
}

run_profile_reentry() {
  local profile_home="$TMPDIR/profile-home"
  local profile_tools="$TMPDIR/profile-tools"
  mkdir -p "$profile_home" "$profile_tools"
  local profile_iteration=0
  # Each profile operation is a new process.  This catches profile data that
  # only appears to persist because a previous shell left state in memory.
  for init in "$V5_FULL_INIT" "$V6_FULL_INIT" "$V5_FULL_INIT"; do
    local create_profile=no
    if [ "$profile_iteration" -eq 0 ]; then
      create_profile=yes
    fi
    env -i PATH="$BASE_PATH" HOME="$profile_home" IDF_TOOLS_PATH="$profile_tools" \
      INIT="$init" CREATE_PROFILE="$create_profile" bash -c '
        set -euo pipefail
        source "$INIT"
        if [ "$CREATE_PROFILE" = yes ]; then
          test ! -e "$IDF_TOOLS_PATH/idf_component_manager.yml"
          compote config set --profile acceptance --default-namespace espressif >/dev/null
        fi
        compote config list | grep -Fq "Profile: acceptance"
        test "$(compote config path)" = "$IDF_TOOLS_PATH/idf_component_manager.yml"
      ' bash
    profile_iteration=$((profile_iteration + 1))
  done
}

echo "Checking ESP-IDF ${ESP_IDF_MAJOR} runtime"
run_full_commands
run_tools_state
run_profile_reentry
echo "ESP-IDF ${ESP_IDF_MAJOR} runtime checks passed"
