# esp-idf-nix

Nix flake for reproducible [ESP-IDF](https://github.com/espressif/esp-idf) development.

It provides:

- Espressif toolchains for Xtensa and RISC-V targets
- An ESP-IDF-aware Python environment
- An optional packaged ESP-IDF tree with `idf.py` ready to use
- A reusable library for downstream flakes
- `eim`, the ESP-IDF Installation Manager CLI
- A project template for quick scaffolding

Current defaults:

- ESP-IDF: `5.5.4`
- EIM CLI: `0.10.5`

## Quick Start

### Scaffold a new project

```sh
mkdir my-esp32-project
cd my-esp32-project

nix flake init -t github:Cbeck527/esp-idf-nix#default
nix develop
idf.py set-target esp32
idf.py build
```

The template uses the `full` shell, so `idf.py` works immediately.

### Try the flake directly

```sh
# Full shell: toolchains + Python + packaged ESP-IDF
nix develop github:Cbeck527/esp-idf-nix#full

# Tools-only shell: toolchains + Python + OpenOCD + EIM
nix develop github:Cbeck527/esp-idf-nix

# Run the standalone ESP-IDF Installation Manager CLI
nix run github:Cbeck527/esp-idf-nix#eim -- --help
```

## Use in Your Own `flake.nix`

This is the simplest downstream setup. It keeps `nixpkgs` aligned and uses the packaged ESP-IDF shell:

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    esp-idf-nix = {
      url = "github:Cbeck527/esp-idf-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, esp-idf-nix, ... }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      devShells = forAllSystems (
        system:
        let
          env = esp-idf-nix.lib.mkEspIdfEnv { inherit system; };
        in
        {
          default = env.devShells.full;
        }
      );
    };
}
```

If you want to use your own ESP-IDF checkout instead, switch to `env.devShells.default` and set `IDF_PATH` yourself.

## Manage Your Own ESP-IDF Install With EIM

`eim` is useful if you want Espressif-managed installations outside the Nix store. This is separate from the Nix-packaged `esp-idf` output.

```sh
# Show EIM help
nix run github:Cbeck527/esp-idf-nix#eim -- --help

# Install ESP-IDF 5.5.4 into your own directory
nix run github:Cbeck527/esp-idf-nix#eim -- install --idf-versions 5.5.4 --path "$HOME/esp"

# See what EIM has installed
nix run github:Cbeck527/esp-idf-nix#eim -- list

# Mark one version as active
nix run github:Cbeck527/esp-idf-nix#eim -- select 5.5.4
```

Use this path when you want EIM to manage the checkout, tools, and activation scripts in the usual Espressif layout instead of relying on the Nix-managed `full` shell.

## Version Selection

`lib.mkEspIdfEnv` is the pure default path. It works with:

- versions already registered in `data/versions.nix`
- or explicit `srcHash`, `constraintsHash`, and `toolsJson`

The flake's top-level `.#full` shell always uses `defaultVersion`. Registering a new version makes it available through `lib.mkEspIdfEnv`, but it does not change `.#full` unless you also update `defaultVersion`.

Example with the built-in default:

```nix
env = esp-idf-nix.lib.mkEspIdfEnv {
  system = "aarch64-darwin";
};
```

Example with explicit metadata:

```nix
env = esp-idf-nix.lib.mkEspIdfEnv {
  system = "aarch64-darwin";
  version = "5.5.4";
  srcHash = "sha256-rItbBrwItkfJf8tKImAQsiXDR95sr0LqaM51gDZG/nI=";
  constraintsHash = "sha256-TqFUnYsDrTTi9M4xVVaDXcumPBWS9vezhqZt4ffujgQ=";
  toolsJson = ./tools.json;
};
```

If you want an arbitrary upstream ESP-IDF tag without checking metadata into your own repo, use `mkEspIdfEnvFromUpstream`:

```nix
env = esp-idf-nix.lib.mkEspIdfEnvFromUpstream {
  system = "aarch64-darwin";
  version = "5.5.4";
  srcHash = "sha256-rItbBrwItkfJf8tKImAQsiXDR95sr0LqaM51gDZG/nI=";
  constraintsHash = "sha256-TqFUnYsDrTTi9M4xVVaDXcumPBWS9vezhqZt4ffujgQ=";
};
```

For new versions, use the helper:

```sh
nix run github:Cbeck527/esp-idf-nix#prefetch-version -- 5.5.4
```

That prints:

- the ESP-IDF source hash
- the constraints file hash
- the exact `tools.json` content to save under `data/tools/`

To inspect or enter a non-default registered version from this repo directly:

```sh
nix eval --impure --json --expr '
  let
    flake = builtins.getFlake (toString ./.);
  in
  builtins.attrNames (
    (flake.lib.mkEspIdfEnv {
      system = builtins.currentSystem;
      version = "6.0";
    }).packages
  )
'

nix develop --impure --expr '
  let
    flake = builtins.getFlake (toString ./.);
  in
  (flake.lib.mkEspIdfEnv {
    system = builtins.currentSystem;
    version = "6.0";
  }).devShells.full
' -c true
```

## Flake Outputs

### Dev shells

| Shell | Command | Includes |
|---|---|---|
| `default` | `nix develop` | Toolchains, Python env, CMake, Ninja, OpenOCD, EIM |
| `full` | `nix develop .#full` | `default` plus packaged ESP-IDF with `idf.py` on `PATH` |

### Packages

| Package | Command | Description |
|---|---|---|
| `default` | `nix run` | Runs `eim` |
| `eim` | `nix run .#eim -- --help` | ESP-IDF Installation Manager CLI |
| `esp-idf` | `nix build .#esp-idf` | ESP-IDF source tree packaged in the Nix store |
| `prefetch-version` | `nix run .#prefetch-version -- 5.5.4` | Fetch helper for registering new ESP-IDF versions |
| `xtensa-esp-elf` | `nix build .#xtensa-esp-elf` | Xtensa GCC toolchain |
| `riscv32-esp-elf` | `nix build .#riscv32-esp-elf` | RISC-V GCC toolchain |
| `xtensa-esp-elf-gdb` | `nix build .#xtensa-esp-elf-gdb` | Xtensa GDB |
| `riscv32-esp-elf-gdb` | `nix build .#riscv32-esp-elf-gdb` | RISC-V GDB |
| `openocd-esp32` | `nix build .#openocd-esp32` | OpenOCD debugger |
| `esp32ulp-elf` | `nix build .#esp32ulp-elf` | ULP coprocessor toolchain |
| `esp-rom-elfs` | `nix build .#esp-rom-elfs` | ROM ELFs for debug symbols |

## Supported Platforms

- `x86_64-linux`
- `aarch64-linux`
- `x86_64-darwin`
- `aarch64-darwin`

## How It Works

1. The flake keeps a checked-in registry of known-good ESP-IDF metadata in `data/versions.nix`.
2. The pure `mkEspIdfEnv` path reads `tools.json` from the repo for registered versions instead of fetching it during evaluation.
3. The dynamic `mkEspIdfEnvFromUpstream` path can still read `tools.json` from an upstream ESP-IDF tag when you opt into that behavior.
4. Toolchain packages are generated from Espressif’s `tools.json` metadata.
5. The packaged `esp-idf` output includes deterministic git metadata so `git describe` still works inside the Nix store.

## Troubleshooting

### `IDF_PATH` is not set

You are in the `default` shell. Either:

- set `IDF_PATH` to your own ESP-IDF checkout
- or use `nix develop .#full`

### `mkEspIdfEnv` says a version is unknown

That version is not in `lib.knownVersions`, and you did not pass explicit metadata.

Use one of these options:

- add the version to your own checked-in metadata and call `mkEspIdfEnv`
- pass `srcHash`, `constraintsHash`, and `toolsJson` directly
- or switch to `mkEspIdfEnvFromUpstream`
