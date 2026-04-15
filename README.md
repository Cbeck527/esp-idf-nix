# esp-idf-nix

Nix flake for reproducible [ESP-IDF](https://github.com/espressif/esp-idf) development.

It provides:

- Espressif toolchains for Xtensa and RISC-V targets
- An ESP-IDF-aware Python environment
- A packaged ESP-IDF tree with `idf.py` ready to use
- Reusable library helpers for downstream flakes
- `eim`, the ESP-IDF Installation Manager CLI
- Separate project templates for the supported major release lines

Current major aliases:

- `v5` -> `5.5.4`
- `v6` -> `6.0`

## Quick Start

### Scaffold a new project

```sh
mkdir my-esp32-project
cd my-esp32-project

nix flake init -t github:Cbeck527/esp-idf-nix#v5
# or:
# nix flake init -t github:Cbeck527/esp-idf-nix#v6

nix develop
idf.py set-target esp32
idf.py build
```

The generated project uses the packaged ESP-IDF shell for its chosen major version.

### Try the flake directly

```sh
# Full shells
nix develop github:Cbeck527/esp-idf-nix#v5
nix develop github:Cbeck527/esp-idf-nix#v6

# Tools-only shells
nix develop github:Cbeck527/esp-idf-nix#v5-tools
nix develop github:Cbeck527/esp-idf-nix#v6-tools

# Standalone ESP-IDF Installation Manager CLI
nix run github:Cbeck527/esp-idf-nix#eim -- --help
```

## Use in Your Own `flake.nix`

Use `mkEspIdfEnvForMajor` when you want to stay on the latest registered release for a major line:

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
          env = esp-idf-nix.lib.mkEspIdfEnvForMajor {
            inherit system;
            major = "6";
          };
        in
        {
          default = env.devShells.full;
        }
      );
    };
}
```

If you want a specific registered release instead of a floating major alias, use `mkEspIdfEnv` with an explicit `version`.

## Exact Version Selection

`mkEspIdfEnvForMajor` resolves `v5` and `v6` through `lib.latestByMajor`.

```nix
env = esp-idf-nix.lib.mkEspIdfEnvForMajor {
  system = "aarch64-darwin";
  major = "6";
};
```

`mkEspIdfEnv` is the pure exact-version path for registered releases or explicit metadata.

```nix
env = esp-idf-nix.lib.mkEspIdfEnv {
  system = "aarch64-darwin";
  version = "5.5.4";
};
```

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
  version = "6.0";
  srcHash = "sha256-YhON/zUFOVTh8UEvujAXsd9IPaaNmSIP+dSZDE5fyqw=";
  constraintsHash = "sha256-Q9aRPdmUB/qyhV+WMl3E363RSk7qPtNqq/Nh5Z0ZQoo=";
};
```

To inspect the exact packages for a registered version:

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
```

## Versioned Tools and Packages

The top-level flake exposes versioned packages for version-dependent artifacts:

- `esp-idf-v5`, `esp-idf-v6`
- `xtensa-esp-elf-v5`, `xtensa-esp-elf-v6`
- `xtensa-esp-elf-gdb-v5`, `xtensa-esp-elf-gdb-v6`
- `riscv32-esp-elf-v5`, `riscv32-esp-elf-v6`
- `riscv32-esp-elf-gdb-v5`, `riscv32-esp-elf-gdb-v6`
- `openocd-esp32-v5`, `openocd-esp32-v6`
- `esp32ulp-elf-v5`, `esp32ulp-elf-v6`
- `esp-rom-elfs-v5`, `esp-rom-elfs-v6`

Examples:

```sh
nix build .#esp-idf-v6
nix build .#openocd-esp32-v6
nix build .#xtensa-esp-elf-v5
```

Unversioned packages remain available only for artifacts that are not tied to an ESP-IDF major:

- `eim`
- `prefetch-version`

## Manage Your Own ESP-IDF Install With EIM

`eim` is useful if you want Espressif-managed installations outside the Nix store. This is separate from the Nix-packaged `esp-idf` output.

```sh
nix run github:Cbeck527/esp-idf-nix#eim -- --help
nix run github:Cbeck527/esp-idf-nix#eim -- install --idf-versions 5.5.4 --path "$HOME/esp"
nix run github:Cbeck527/esp-idf-nix#eim -- list
nix run github:Cbeck527/esp-idf-nix#eim -- select 5.5.4
```

## Add a New ESP-IDF Version

Use the helper to prefetch the hashes and upstream `tools.json`:

```sh
nix run github:Cbeck527/esp-idf-nix#prefetch-version -- 5.5.5
```

Then:

- add the exact release to `data/versions.nix`
- save the printed JSON under `data/tools/`
- update `latestByMajor."5"` or `latestByMajor."6"` if that release should become the new `v5` or `v6` alias

See [data/README.md](./data/README.md) for the exact workflow.

## Supported Platforms

- `x86_64-linux`
- `aarch64-linux`
- `x86_64-darwin`
- `aarch64-darwin`

## Troubleshooting

### `IDF_PATH` is not set

You are in a tools-only shell. Either:

- set `IDF_PATH` to your own ESP-IDF checkout
- or use a full shell such as `nix develop .#v5` or `nix develop .#v6`

### `mkEspIdfEnv` says a version is unknown

That version is not in `lib.knownVersions`, and you did not pass explicit metadata.

Use one of these options:

- add the version to your own checked-in metadata and call `mkEspIdfEnv`
- pass `srcHash`, `constraintsHash`, and `toolsJson` directly
- or switch to `mkEspIdfEnvFromUpstream`
