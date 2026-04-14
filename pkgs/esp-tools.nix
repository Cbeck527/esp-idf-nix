# pkgs/esp-tools.nix
#
# Generates a Nix derivation for each prebuilt ESP-IDF toolchain from
# the parsed tools.json data. This is the core of the flake -- it
# turns Espressif's tool metadata into reproducible Nix packages.
#
# ── How Nix files work ──
# A .nix file is just an expression. This file evaluates to a function
# that takes an attrset and returns an attrset of derivations. Think
# of it like a module that exports packages.
#
# tools.json is read from the fetched ESP-IDF source in flake.nix,
# parsed with builtins.fromJSON, and passed here as `toolsJson`.
# This means tool versions always match the ESP-IDF version -- no
# vendored file to keep in sync.
#
# Called from flake.nix with:
#   espTools = import ./pkgs/esp-tools.nix { inherit pkgs lib espPlatform toolsJson; };

{ pkgs, lib, espPlatform, toolsJson }:

let

  # ── Per-tool Linux library dependencies ───────────────────────────
  # On Linux, autoPatchelfHook rewrites ELF binaries to find shared
  # libraries in /nix/store/ instead of /usr/lib/. It needs to know
  # which packages provide the .so files each tool needs.
  #
  # Different tools link against different libraries:
  #   - GCC toolchains: just libstdc++ and zlib
  #   - GDB: adds ncurses (TUI), Python (scripting), expat (XML)
  #   - OpenOCD: adds USB libraries (for JTAG debugger communication)
  #   - ROM ELFs: no binaries at all, just data files
  linuxBuildInputs = with pkgs; {
    xtensa-esp-elf = [ stdenv.cc.cc.lib zlib ];
    riscv32-esp-elf = [ stdenv.cc.cc.lib zlib ];
    xtensa-esp-elf-gdb = [ stdenv.cc.cc.lib zlib ncurses5 expat python3 gmp mpfr ];
    riscv32-esp-elf-gdb = [ stdenv.cc.cc.lib zlib ncurses5 expat python3 gmp mpfr ];
    esp32ulp-elf = [ stdenv.cc.cc.lib zlib ];
    openocd-esp32 = [ stdenv.cc.cc.lib zlib libusb1 hidapi libftdi1 ];
    esp-rom-elfs = [ ]; # just data files, no binaries to patch
  };

  # ── Per-tool derivation overrides ──────────────────────────────────
  # Some tools need special handling. We define overrides as attrsets
  # that get merged into the derivation with `//` (attrset merge).
  # This is a common Nix pattern: define defaults, then merge overrides.
  toolOverrides = {
    # esp-rom-elfs: tarball contains bare .elf files with no wrapper
    # directory, so mkDerivation's auto-detection fails. We tell it
    # the source root is the current directory.
    esp-rom-elfs = {
      sourceRoot = ".";
      # These are cross-compiled ROM ELF files (data), not host binaries.
      # The fixup phase would try to patch them and fail.
      dontFixup = true;
    };
  };

  # ── Generic tool builder ──────────────────────────────────────────
  # Takes one tool entry from tools.json and produces a Nix derivation.
  #
  # This is a function (toolDef: ...) -- Nix's lambda syntax. In Nix,
  # functions always take exactly one argument. Multi-argument functions
  # are done by currying or by taking an attrset (which is what we do
  # in the file-level function above).
  mkEspTool = toolDef:
    let
      # ── Find the recommended version ──
      # lib.findFirst takes a predicate, a fallback, and a list.
      # It returns the first element where the predicate is true.
      recVersion = lib.findFirst (v: v.status == "recommended") (builtins.head toolDef.versions)
        toolDef.versions;

      # ── Resolve platform-specific download ──
      # Most tools have per-platform entries (linux-amd64, macos-arm64, etc.)
      # Some (like esp-rom-elfs) use "any" for a single platform-independent
      # download. We try our specific platform first, then fall back to "any".
      #
      # The `or` keyword provides a fallback if an attribute doesn't exist:
      #   attrset.${key} or defaultValue
      platformSrc = recVersion.${espPlatform} or recVersion.any or null;
    in
    # If this tool has no download for our platform, return null.
    # The caller filters these out.
    if platformSrc == null then
      null
    else
      pkgs.stdenv.mkDerivation (
        {
          pname = toolDef.name;
          version = recVersion.name;

          src = pkgs.fetchurl {
            inherit (platformSrc) url sha256;
          };

          nativeBuildInputs =
            lib.optionals pkgs.stdenv.hostPlatform.isLinux [
              pkgs.autoPatchelfHook
            ]
            ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
              # Provides `codesign` that works inside the Nix sandbox
              # (Apple's /usr/bin/codesign is blocked by the sandbox)
              pkgs.darwin.sigtool
            ];

          buildInputs = lib.optionals pkgs.stdenv.hostPlatform.isLinux (
            linuxBuildInputs.${toolDef.name} or [
              pkgs.stdenv.cc.cc.lib
              pkgs.zlib
            ]
          );

          dontBuild = true;

          installPhase = ''
            cp -r . $out
          '';

          # ── macOS code signing ──
          # Prebuilt toolchains contain .so plugins that the assembler
          # loads via dlopen(). macOS requires loaded libraries to have
          # compatible code signatures with the host process. Nix's
          # default fixup signs binaries in bin/ but misses .so plugins
          # in lib/. We re-sign everything with ad-hoc signatures.
          postFixup = lib.optionalString pkgs.stdenv.hostPlatform.isDarwin ''
            # Re-sign ALL Mach-O binaries and shared libs with ad-hoc
            # signatures so they have matching Team IDs for dlopen().
            find $out -type f -perm /111 -exec \
              sh -c 'file "$1" | grep -q Mach-O && codesign -f -s - "$1" 2>/dev/null || true' _ {} \;
          '';

          meta = {
            description = toolDef.description;
            homepage = toolDef.info_url;
            platforms = [
              "x86_64-linux"
              "aarch64-linux"
              "x86_64-darwin"
              "aarch64-darwin"
            ];
          };
        }
        # Merge in per-tool overrides. `//` is attrset merge -- keys
        # from the right side override keys from the left.
        // (toolOverrides.${toolDef.name} or { })
      );

  # ── Filter to "always install" tools and build them ───────────────
  # This is a functional pipeline:
  #   1. builtins.filter: keep only tools with install = "always"
  #   2. lib.concatMap: for each tool, call mkEspTool and wrap in a
  #      name/value pair (or empty list if the tool returned null)
  #   3. lib.listToAttrs: convert [{name; value}] pairs into an attrset
  #
  # The result is something like:
  #   { xtensa-esp-elf = <derivation>; riscv32-esp-elf = <derivation>; ... }
  alwaysTools = builtins.filter (t: t.install == "always") toolsJson.tools;

in
lib.listToAttrs (
  lib.concatMap (
    toolDef:
    let
      pkg = mkEspTool toolDef;
    in
    if pkg != null then
      [
        {
          name = toolDef.name;
          value = pkg;
        }
      ]
    else
      [ ]
  ) alwaysTools
)
