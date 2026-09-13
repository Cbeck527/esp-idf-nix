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
The packaged SDK retains deterministic Git metadata because upstream `idf.py`
reads Git revision information; `version.txt` alone is insufficient.

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
  system = "aarch64-darwin";
  version = "5.5.4";
};
```

When a project needs custom Nixpkgs configuration, this complete v5 example
includes the `ecdsa` exception required by the pinned v5 Python dependencies:

```nix
env = esp-idf-nix.lib.mkEspIdfEnv {
  pkgs = import nixpkgs {
    system = "aarch64-darwin";
    config.allowInsecurePredicate = pkg: (pkg.pname or "") == "ecdsa";
  };
  system = "aarch64-darwin";
  version = "5.5.4";
};
```

For a release that is not registered in `lib.knownVersions`, pass the exact
source hash, constraints snapshot, and tools manifest you keep beside your
flake directly to `mkEspIdfEnv`. The version still has to belong to a
supported Python profile (currently ESP-IDF 5.5 or 6.0); adding another
release line requires a maintainer to add and validate its profile.

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

## Python and tool state

Every shell uses one Nix-managed Python environment. It exports
`IDF_PYTHON_ENV_PATH` and sets
[`IDF_PYTHON_CHECK_CONSTRAINTS=no`](https://docs.espressif.com/projects/esp-idf/en/stable/esp32/api-guides/tools/idf-tools.html#custom-installation); the effective
ESP-IDF constraints are immutable store files and are checked explicitly by
the flake's Nix acceptance checks. `IDF_TOOLS_PATH` is honored when supplied,
and otherwise defaults to `~/.espressif`. Component-manager profiles therefore
remain writable and persist across shell sessions.

The current Python profiles contain four deliberate constraint relaxations:
`cryptography>=2.1.4`, `click>=7.0`, `pyparsing>=3.1.0`, and
`esp-idf-nvs-partition-gen>=0.1.9`. Nix checks require each upstream line to be
present exactly once before producing the immutable effective constraints;
maintainers adding a new ESP-IDF line must add its profile and validate that
profile's effective constraints.

The tools-only shell supplies the compilers and Python tools while leaving
your SDK checkout in `IDF_PATH`. Invoke that checkout explicitly when needed:

```sh
export IDF_PATH="$HOME/src/esp-idf"
nix develop github:Cbeck527/esp-idf-nix#v6-tools --command \
  python "$IDF_PATH/tools/idf.py" build
```

To add project tools, extend the exported shell while preserving its
environment and initialization:

```nix
devShells.default = esp-idf-nix.devShells.${system}.v5.overrideAttrs (old: {
  # Keep the exported SDK variables and shell hook, then add one package.
  nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.hello ];
});
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
supports manual runs; it evaluates the package and shell graph, then runs the
runtime, archive, profile-state, EIM help, and per-target firmware checks.
Only runs on the upstream `main` branch publish.

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

## License

The original Nix expressions, scripts, project templates, and documentation in this
repository are licensed under the [MIT License](LICENSE).

Vendored metadata under `data/tools/` and `data/constraints/` is third-party
material; see [metadata provenance and licensing](data/README.md#provenance-and-licensing).

ESP-IDF, the toolchains, and other packages fetched by this flake retain their own
upstream licenses.
