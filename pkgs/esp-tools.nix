{ pkgs, lib, espPlatform, toolsJson }:

let

  linuxBuildInputs = with pkgs; {
    xtensa-esp-elf = [ stdenv.cc.cc.lib zlib ];
    riscv32-esp-elf = [ stdenv.cc.cc.lib zlib ];
    xtensa-esp-elf-gdb = [ stdenv.cc.cc.lib zlib ncurses5 expat python3 gmp mpfr ];
    riscv32-esp-elf-gdb = [ stdenv.cc.cc.lib zlib ncurses5 expat python3 gmp mpfr ];
    esp32ulp-elf = [ stdenv.cc.cc.lib zlib ];
    openocd-esp32 = [ stdenv.cc.cc.lib zlib libusb1 hidapi libftdi1 ];
    esp-rom-elfs = [ ];
  };

  toolOverrides = {
    esp-rom-elfs = {
      sourceRoot = ".";
      # ROM ELFs are data files, not host binaries.
      dontFixup = true;
    };
  };

  mkEspTool = toolDef:
    let
      recVersion = lib.findFirst (v: v.status == "recommended") (builtins.head toolDef.versions)
        toolDef.versions;

      # Some tools publish one archive for every host, others use `any`.
      platformSrc = recVersion.${espPlatform} or recVersion.any or null;
    in
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

          # Re-sign Mach-O files in lib/ so dlopen() works on macOS.
          postFixup = lib.optionalString pkgs.stdenv.hostPlatform.isDarwin ''
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
        // (toolOverrides.${toolDef.name} or { })
      );

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
