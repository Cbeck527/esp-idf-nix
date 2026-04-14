# esp-idf-nix

Nix flake for reproducible [ESP-IDF](https://github.com/espressif/esp-idf) development.
It provides:

- Espressif toolchains (Xtensa + RISC-V)
- ESP-IDF-aware Python environment
- Optional packaged ESP-IDF source (`idf.py` ready)
- Reusable `mkEspIdfEnv` function for downstream flakes
- A project template for quick scaffolding

Current defaults in `flake.nix`:

- ESP-IDF: `5.5.4`
- EIM CLI: `0.10.5`

## Quick Start

### 1) Scaffold a new ESP-IDF project

```sh
mkdir my-esp32-project && cd my-esp32-project
nix flake init -t github:Cbeck527/esp-idf-nix#default
nix develop
idf.py set-target esp32
idf.py build
```

The template uses the **full** dev shell by default, so `idf.py` is available immediately.

### 2) Try this flake without scaffolding

```sh
# Full shell: toolchains + packaged ESP-IDF + idf.py
nix develop github:Cbeck527/esp-idf-nix#full

# Tools-only shell: toolchains + Python + OpenOCD + EIM
nix develop github:Cbeck527/esp-idf-nix

# Run ESP-IDF Installation Manager CLI (default package)
nix run github:Cbeck527/esp-idf-nix
```

## Flake Outputs

### Dev shells

| Shell | Command | Includes |
|---|---|---|
| `default` | `nix develop` | Toolchains, Python env, CMake, Ninja, OpenOCD, EIM |
| `full` | `nix develop .#full` | `default` + packaged ESP-IDF with `idf.py` on `PATH` |

Use `default` when you manage your own ESP-IDF checkout (`IDF_PATH`).
Use `full` when you want a self-contained setup.

### Packages

| Package | Command | Description |
|---|---|---|
| `eim` (default) | `nix run` | ESP-IDF Installation Manager CLI |
| `esp-idf` | `nix build .#esp-idf` | ESP-IDF source tree packaged in Nix store |
| `xtensa-esp-elf` | `nix build .#xtensa-esp-elf` | Xtensa GCC toolchain |
| `riscv32-esp-elf` | `nix build .#riscv32-esp-elf` | RISC-V GCC toolchain |
| `xtensa-esp-elf-gdb` | `nix build .#xtensa-esp-elf-gdb` | Xtensa GDB |
| `riscv32-esp-elf-gdb` | `nix build .#riscv32-esp-elf-gdb` | RISC-V GDB |
| `openocd-esp32` | `nix build .#openocd-esp32` | OpenOCD debugger |
| `esp32ulp-elf` | `nix build .#esp32ulp-elf` | ULP coprocessor toolchain |
| `esp-rom-elfs` | `nix build .#esp-rom-elfs` | ROM ELFs for debug symbols |

## Use in Your Own `flake.nix`

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    esp-idf-nix.url = "github:Cbeck527/esp-idf-nix";
  };

  outputs = { nixpkgs, esp-idf-nix, ... }:
    let
      system = "aarch64-darwin"; # or x86_64-linux, aarch64-linux, x86_64-darwin
      env = esp-idf-nix.lib.mkEspIdfEnv { inherit system; };
    in {
      devShells.${system}.default = env.devShells.full;
    };
}
```

## Override ESP-IDF Version

`mkEspIdfEnv` supports version overrides:

```nix
env = esp-idf-nix.lib.mkEspIdfEnv {
  system = "aarch64-darwin";
  version = "5.5.4";
  srcHash = "sha256-...";
  constraintsHash = "sha256-...";
};
```

Fetch hashes with:

```sh
# ESP-IDF source hash (with submodules)
nix run nixpkgs#nix-prefetch-github -- --fetch-submodules espressif esp-idf --rev v5.5.4

# constraints hash (major.minor file)
nix store prefetch-file --json "https://dl.espressif.com/dl/esp-idf/espidf.constraints.v5.5.txt" | jq -r .hash
```

## Supported Platforms

- `x86_64-linux`
- `aarch64-linux`
- `x86_64-darwin`
- `aarch64-darwin`

## How It Works

1. Fetches ESP-IDF source (with submodules) via `fetchFromGitHub`
2. Parses `tools/tools.json` from that source at evaluation time
3. Builds toolchain derivations from Espressif download metadata
4. Applies platform fixups:
   - Linux: `autoPatchelfHook` for ELF runtime paths
   - macOS: ad-hoc codesigning for `dlopen()` compatibility
5. Builds/assembles required ESP-IDF Python tooling (custom + nixpkgs)
6. Packages ESP-IDF with a minimal `.git` state so `git describe` works
7. Exposes pre-wired shells with `IDF_PATH`, `IDF_TOOLS_PATH`, and related vars

## Troubleshooting

### `nix develop` says `IDF_PATH` is not set

You are in the tools-only shell. Either:

- set `IDF_PATH` to your own checkout, or
- use `nix develop .#full`

### Hash mismatch when evaluating ESP-IDF source

If Espressif source content changes for a selected revision, update `srcHash` in `flake.nix` using the `nix-prefetch-github` command above.
