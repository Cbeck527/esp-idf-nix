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
- `v6` -> `6.0.2`

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

### Use the binary cache

The flake and both project templates configure the public
[`esp-idf-nix` Cachix cache](https://esp-idf-nix.cachix.org). Accept the cache settings
when Nix prompts, or use `nix develop --accept-flake-config`.

For existing projects, flakes that use `esp-idf-nix` as an input, or system-wide
setup:

```sh
cachix use esp-idf-nix
```

Alternatively, add these settings to your Nix configuration:

```ini
extra-substituters = https://esp-idf-nix.cachix.org
extra-trusted-public-keys = esp-idf-nix.cachix.org-1:6qHkAxmub00GqSujpkTqbL3XZvT6d4g8/13FcL+wrpQ=
```

The cache is public, so downloads need no token. Templates follow this flake's
locked nixpkgs revision to match the packages built by CI. Overriding nixpkgs,
applying overlays, or selecting a release that CI does not build can require local
builds. Nix builds any paths missing from the cache as usual.

### Try the flake directly

```sh
# Default shell (latest supported major)
nix develop github:Cbeck527/esp-idf-nix

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

All library helpers accept an optional `pkgs` argument so downstream flakes can preserve their own overlays and nixpkgs configuration.

Use `mkEspIdfEnvForMajor` when you want to stay on the latest registered release for a major line:

```nix
{
  inputs = {
    esp-idf-nix.url = "github:Cbeck527/esp-idf-nix";
    nixpkgs.follows = "esp-idf-nix/nixpkgs";
  };

  outputs =
    { nixpkgs, esp-idf-nix, ... }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      devShells = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };

          env = esp-idf-nix.lib.mkEspIdfEnvForMajor {
            inherit
              pkgs
              system
              ;
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
  pkgs = import nixpkgs { system = "aarch64-darwin"; };
  system = "aarch64-darwin";
  major = "6";
};
```

`mkEspIdfEnv` is the pure exact-version path for registered releases or explicit metadata.

```nix
env = esp-idf-nix.lib.mkEspIdfEnv {
  pkgs = import nixpkgs { system = "aarch64-darwin"; };
  system = "aarch64-darwin";
  version = "5.5.4";
};
```

Note: when you pass your own `pkgs`, ESP-IDF v5 environments need nixpkgs' insecure ecdsa allowed, e.g. `config.allowInsecurePredicate = pkg: (pkg.pname or "") == "ecdsa";`.

```nix
env = esp-idf-nix.lib.mkEspIdfEnv {
  pkgs = import nixpkgs { system = "aarch64-darwin"; };
  system = "aarch64-darwin";
  version = "5.5.4";
  srcHash = "sha256-rItbBrwItkfJf8tKImAQsiXDR95sr0LqaM51gDZG/nI=";
  # curl -fsSLO https://dl.espressif.com/dl/esp-idf/espidf.constraints.v5.5.txt
  constraintsFile = ./espidf.constraints.v5.5.txt;
  toolsJson = ./tools.json;
};
```

If you want an arbitrary upstream ESP-IDF tag without registering it in `lib.knownVersions`, use `mkEspIdfEnvFromUpstream` with explicit metadata:

```nix
env = esp-idf-nix.lib.mkEspIdfEnvFromUpstream {
  pkgs = import nixpkgs { system = "aarch64-darwin"; };
  system = "aarch64-darwin";
  version = "6.0.2";
  srcHash = "sha256-dVdJ+aUjMJyWoz+wOwA0R6XH3JRq0VBpC1sAH/aLECs=";
  # curl -fsSLO https://dl.espressif.com/dl/esp-idf/espidf.constraints.v6.0.txt
  constraintsFile = ./espidf.constraints.v6.0.txt;
  toolsJson = ./tools.json;
};
```

This keeps the helper usable in strict Nix environments without import-from-derivation.

To inspect the exact packages for a registered version:

```sh
nix eval --impure --json --expr '
  let
    flake = builtins.getFlake (toString ./.);
  in
  builtins.attrNames (
    (flake.lib.mkEspIdfEnv {
      system = builtins.currentSystem;
      version = "6.0.2";
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

Use the helper to prefetch the source hash and write upstream snapshots (run from the repository root):

```sh
nix run github:Cbeck527/esp-idf-nix#prefetch-version -- 5.5.5
```

Then:

- add the exact release to `data/versions.nix`
- check in `data/tools/v<version>.json` and `data/constraints/v<version>.txt`
- update `latestByMajor."5"` or `latestByMajor."6"` if that release should become the new `v5` or `v6` alias

See [data/README.md](./data/README.md) for the exact workflow.

## Supported Platforms

- `x86_64-linux`
- `aarch64-linux`
- `aarch64-darwin`

## CI and Cache Publishing

[GitHub Actions](.github/workflows/build.yml) builds every exported package and
enters every development shell on native runners for all supported platforms:

| Nix system | GitHub runner |
| --- | --- |
| `x86_64-linux` | `ubuntu-24.04` |
| `aarch64-linux` | `ubuntu-24.04-arm` |
| `aarch64-darwin` | `macos-15` |

Pushes to `main` in `Cbeck527/esp-idf-nix` publish build results and their dependencies
to Cachix. Pull requests build with read-only cache access. The workflow also
supports manual runs; only runs on the upstream `main` branch publish.

To enable publishing, create a per-cache Cachix token with write access to
`esp-idf-nix`, then add it as the repository Actions secret `CACHIX_AUTH_TOKEN` under **Settings →
Secrets and variables → Actions**. Publishing jobs fail with a setup message if the
secret is missing. Run **Build and cache** on `main` after adding the secret to
populate the cache.

## Troubleshooting

### `IDF_PATH` is not set

You are in a tools-only shell. Either:

- set `IDF_PATH` to your own ESP-IDF checkout
- or use a full shell such as `nix develop .#v5` or `nix develop .#v6`

### `mkEspIdfEnv` says a version is unknown

That version is not in `lib.knownVersions`, and you did not pass explicit metadata.

Use one of these options:

- add the version to your own checked-in metadata and call `mkEspIdfEnv`
- pass `srcHash`, `constraintsFile`, and `toolsJson` directly
- or call `mkEspIdfEnvFromUpstream` with `srcHash`, `constraintsFile`, and `toolsJson`
