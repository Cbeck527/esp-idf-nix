{
  pkgs,
  lib,
  espPlatform,
  toolsJson,
  pythonEnv,
}:

let

  linuxBuildInputs = with pkgs; {
    xtensa-esp-elf = [
      stdenv.cc.cc.lib
      zlib
    ];
    riscv32-esp-elf = [
      stdenv.cc.cc.lib
      zlib
    ];
    xtensa-esp-elf-gdb = [
      stdenv.cc.cc.lib
      zlib
      ncurses5
      expat
      python3
      gmp
      mpfr
    ];
    riscv32-esp-elf-gdb = [
      stdenv.cc.cc.lib
      zlib
      ncurses5
      expat
      python3
      gmp
      mpfr
    ];
    esp32ulp-elf = [
      stdenv.cc.cc.lib
      zlib
    ];
    openocd-esp32 = [
      stdenv.cc.cc.lib
      zlib
      libusb1
      hidapi
      libftdi1
    ];
    esp-rom-elfs = [ ];
  };

  toolOverrides = {
    esp-rom-elfs = {
      sourceRoot = ".";
      # ROM ELFs are data files, not host binaries.
      dontFixup = true;
    };
  };

  mkEspTool =
    toolDef:
    let
      recVersion = lib.findFirst (
        v: v.status == "recommended"
      ) (builtins.head toolDef.versions) toolDef.versions;

      # Some tools publish one archive for every host, others use `any`.
      platformSrc = recVersion.${espPlatform} or recVersion.any or null;
      isLinuxGdb = pkgs.stdenv.hostPlatform.isLinux && lib.hasSuffix "-gdb" toolDef.name;
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

          dontStrip = lib.elem toolDef.name [
            "xtensa-esp-elf"
            "riscv32-esp-elf"
            "esp32ulp-elf"
          ];

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
              "aarch64-darwin"
            ];
          };
        }
        // (toolOverrides.${toolDef.name} or { })
        // lib.optionalAttrs isLinuxGdb {
          nativeBuildInputs = [
            pkgs.autoPatchelfHook
            pkgs.makeWrapper
          ];

          preFixup = ''
            # Upstream bundles one GDB per Python version; keep the one Nix provides.
            mkdir -p "$out/libexec"
            mv "$out/bin/${toolDef.name}-${pkgs.python3.pythonVersion}" "$out/libexec/${toolDef.name}"
            rm -f "$out/bin/${toolDef.name}"-[0-9]* "$out/bin/${toolDef.name}-no-python"

            for gdb in "$out"/bin/*-elf-gdb; do
              args=(
                --set PYTHONHOME "${pkgs.python3}"
                --prefix PYTHONPATH : "${pythonEnv}/${pkgs.python3.sitePackages}"
              )
              ${lib.optionalString (toolDef.name == "xtensa-esp-elf-gdb") ''
                chip=$(basename "$gdb" -elf-gdb)
                chip=''${chip#xtensa-}
                args+=(--set XTENSA_GNU_CONFIG "$out/lib/xtensa_$chip.so")
              ''}
              makeWrapper "$out/libexec/${toolDef.name}" "$gdb" "''${args[@]}"
            done
          '';

          doInstallCheck = true;
          installCheckPhase = ''
            runHook preInstallCheck
            for gdb in "$out"/bin/*-elf-gdb; do
              env -i "$gdb" --batch --nx --quiet \
                -ex 'python import gdb, freertos_gdb, esptool, sys; assert sys.version.startswith("${pkgs.python3.pythonVersion}.")'
            done
            runHook postInstallCheck
          '';
        }
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
