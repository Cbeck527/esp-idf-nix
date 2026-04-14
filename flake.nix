{
  description = "ESP-IDF Development Tools";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    let
      # ── mkEspIdfEnv ─────────────────────────────────────────────────
      # The core function of this flake. Takes an ESP-IDF version and
      # returns packages + devShells with everything wired up.
      #
      # Consumers can override the ESP-IDF version:
      #
      #   env = esp-idf-nix.lib.mkEspIdfEnv {
      #     system = "aarch64-darwin";
      #     version = "5.5.4";
      #     srcHash = "sha256-XXXX";
      #     constraintsHash = "sha256-YYYY";
      #   };
      #   devShells.default = env.devShells.full;
      #
      mkEspIdfEnv =
        {
          system,
          version ? "5.5.4",
          srcHash ? "sha256-sV/eL3jRG9GdaQNByBypmH5ZKmZoOnWCEY1ABySIeac=",
          constraintsHash ? "sha256-5r1aDNoMOJjAIzcDsqF7RXFv3PkwzPJpfokKQ5jA6SM=",
        }:
        let
          pkgs = import nixpkgs {
            inherit system;
            # esptool depends on `ecdsa` which has CVE-2024-23342 (timing
            # side-channel in ECDSA signing -- not relevant for flashing).
            config.permittedInsecurePackages = [
              "python3.13-ecdsa-0.19.1"
            ];
          };
          lib = pkgs.lib;

          # ── Platform mapping ──────────────────────────────────────
          espPlatform =
            {
              x86_64-linux = "linux-amd64";
              aarch64-linux = "linux-arm64";
              x86_64-darwin = "macos";
              aarch64-darwin = "macos-arm64";
            }
            .${system};

          # ── Fetch ESP-IDF source ──────────��───────────────────────
          # fetchFromGitHub is a fixed-output derivation -- its result
          # is a store path available at *evaluation time*. This lets
          # us read tools.json from the fetched source without vendoring
          # it, and tool versions always match the ESP-IDF version.
          idfSrc = pkgs.fetchFromGitHub {
            owner = "espressif";
            repo = "esp-idf";
            rev = "v${version}";
            fetchSubmodules = true;
            hash = srcHash;
          };

          # ── Parse tools.json from the fetched source ──────────────
          toolsJson = builtins.fromJSON (builtins.readFile "${idfSrc}/tools/tools.json");

          # ── EIM (ESP-IDF Installation Manager) CLI ────────────────
          eimVersion = "0.10.5";

          eimSources = {
            x86_64-linux = {
              url = "https://github.com/espressif/idf-im-ui/releases/download/v${eimVersion}/eim-cli-linux-x64.zip";
              hash = "sha256-DnzBqyuAsbmokLZ+RhE6FS35UgCWPLSutErNYOJzJW4=";
            };
            aarch64-linux = {
              url = "https://github.com/espressif/idf-im-ui/releases/download/v${eimVersion}/eim-cli-linux-aarch64.zip";
              hash = "sha256-W7Octtd7RveKsaEcJpG/Ebiinp/V1N6O5yzvPL4IHpo=";
            };
            x86_64-darwin = {
              url = "https://github.com/espressif/idf-im-ui/releases/download/v${eimVersion}/eim-cli-macos-x64.zip";
              hash = "sha256-SwvMq/nrzKyEGjKUGmgPreUXGW9l2xgtMytFIbv8yZE=";
            };
            aarch64-darwin = {
              url = "https://github.com/espressif/idf-im-ui/releases/download/v${eimVersion}/eim-cli-macos-aarch64.zip";
              hash = "sha256-rpCTYKPJcwIKW2BzJzOF5/6CikKKXlgKHpTZawMluXE=";
            };
          };

          eim = pkgs.stdenv.mkDerivation {
            pname = "eim";
            version = eimVersion;

            src = pkgs.fetchurl {
              inherit (eimSources.${system}) url hash;
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
              platforms = builtins.attrNames eimSources;
            };
          };

          # ── ESP-IDF Toolchains (from tools.json) ──────────────────
          espTools = import ./pkgs/esp-tools.nix {
            inherit
              pkgs
              lib
              espPlatform
              toolsJson
              ;
          };

          # ── Python packages ──────────��────────────────────────────
          espPython = import ./pkgs/python-packages.nix { inherit pkgs lib; };

          # ── ESP-IDF framework source ──────────────────────────────
          esp-idf = import ./pkgs/esp-idf.nix {
            inherit
              pkgs
              lib
              version
              idfSrc
              constraintsHash
              ;
          };

          # ── Shared devShell packages ──────────────────────────────
          commonPackages =
            (with pkgs; [
              cmake
              ninja
              espPython.pythonEnv
              git
              flex
              bison
              gperf
              dfu-util
              eim
            ])
            ++ builtins.attrValues espTools;

        in
        {
          inherit
            eim
            esp-idf
            espTools
            espPython
            ;

          packages = {
            inherit eim esp-idf;
            default = eim;
          }
          // espTools;

          devShells = {
            # ── default: tools only ──
            default = pkgs.mkShell {
              packages = commonPackages;

              env = {
                ESP_ROM_ELF_DIR = "${espTools.esp-rom-elfs}";
                OPENOCD_SCRIPTS = "${espTools.openocd-esp32}/share/openocd/scripts";
              };

              shellHook = ''
                echo "ESP-IDF development environment (tools only)"
                echo "  Xtensa GCC:  $(xtensa-esp-elf-gcc --version | head -1)"
                echo "  RISC-V GCC:  $(riscv32-esp-elf-gcc --version | head -1)"
                echo "  OpenOCD:     $(openocd --version 2>&1 | head -1)"
                if [ -z "$IDF_PATH" ]; then
                  echo ""
                  echo "  NOTE: IDF_PATH not set. Either:"
                  echo "    export IDF_PATH=/path/to/your/esp-idf"
                  echo "    or use 'nix develop .#full' for packaged ESP-IDF"
                fi
              '';
            };

            # ── full: tools + packaged ESP-IDF ���─
            full = pkgs.mkShell {
              packages = commonPackages;

              env = {
                IDF_PATH = "${esp-idf}";
                IDF_TOOLS_PATH = "${esp-idf}/tools-path";
                IDF_PYTHON_ENV_PATH = "${espPython.pythonEnv}";
                ESP_ROM_ELF_DIR = "${espTools.esp-rom-elfs}";
                OPENOCD_SCRIPTS = "${espTools.openocd-esp32}/share/openocd/scripts";
              };

              shellHook = ''
                export PATH="${esp-idf}/tools:$PATH"

                # Git safe.directory for the nix store path
                export GIT_CONFIG_COUNT=''${GIT_CONFIG_COUNT:-0}
                export GIT_CONFIG_KEY_$GIT_CONFIG_COUNT=safe.directory
                export GIT_CONFIG_VALUE_$GIT_CONFIG_COUNT="${esp-idf}"
                export GIT_CONFIG_COUNT=$((GIT_CONFIG_COUNT + 1))

                echo "ESP-IDF v${version} development environment"
                echo "  IDF_PATH:    $IDF_PATH"
                echo "  Xtensa GCC:  $(xtensa-esp-elf-gcc --version | head -1)"
                echo "  RISC-V GCC:  $(riscv32-esp-elf-gcc --version | head -1)"
                echo "  OpenOCD:     $(openocd --version 2>&1 | head -1)"
                echo ""
                echo "  Ready! Try: idf.py create-project myproject"
              '';
            };
          };
        };
    in
    # ── Flake outputs ─────────────────────────────────────────────────
    # Expose mkEspIdfEnv for consumers who want a different ESP-IDF
    # version, then use it ourselves for the default packages/shells.
    {
      lib.mkEspIdfEnv = mkEspIdfEnv;

      # ── Flake template ──
      # `nix flake init -t github:Cbeck527/esp-idf-nix` scaffolds
      # a new ESP-IDF project with a flake.nix pre-wired to this flake.
      templates.default = {
        path = ./templates/default;
        description = "ESP-IDF project with Nix devShell";
      };
    }
    // flake-utils.lib.eachDefaultSystem (
      system:
      let
        env = mkEspIdfEnv { inherit system; };
      in
      {
        inherit (env) packages devShells;
      }
    );
}
