# Adding an ESP-IDF Version

This directory holds the checked-in metadata for the flake's pure `mkEspIdfEnv` path.

Each supported release needs:

- a `tools.json` snapshot under `data/tools/`
- a constraints snapshot under `data/constraints/`
- an exact entry in `data/versions.nix`

Major aliases are managed separately through `latestByMajor`.

## Provenance and licensing

`versions.nix` and this document are covered by the repository's [MIT License](../LICENSE).
The upstream snapshots below are excluded from that license grant.

### Tool manifests

`tools/v<version>.json` files are snapshots of `tools/tools.json` from the matching
[ESP-IDF release tag](https://github.com/espressif/esp-idf/tags). For example,
`tools/v6.0.2.json` comes from
[ESP-IDF v6.0.2](https://github.com/espressif/esp-idf/blob/v6.0.2/tools/tools.json).

These files retain ESP-IDF's Apache-2.0 license, reproduced in [tools/LICENSE](tools/LICENSE).
The [upstream copyright notice](https://github.com/espressif/esp-idf/blob/v6.0.2/docs/en/COPYRIGHT.rst)
states: Copyright (C) 2015-2023 Espressif Systems.

The `license` fields inside the manifests describe the listed tools, not the
manifests themselves.

### Python constraints

`constraints/v<version>.txt` files are snapshots downloaded from Espressif:

| Snapshots | Upstream source |
| --- | --- |
| `v5.5.4.txt` | [ESP-IDF v5.5 constraints](https://dl.espressif.com/dl/esp-idf/espidf.constraints.v5.5.txt) |
| `v6.0.txt`, `v6.0.1.txt`, `v6.0.2.txt` | [ESP-IDF v6.0 constraints](https://dl.espressif.com/dl/esp-idf/espidf.constraints.v6.0.txt) |

These download URLs are updated in place; the checked-in files preserve the
versions used by this flake. The downloaded files contain no explicit license
notice. Their licensing needs clarification from Espressif; this repository does
not assign them MIT or infer Apache-2.0 from the separate ESP-IDF repository.

## Workflow

1. From the repository root, run the helper for the version you want to add. It writes `data/tools/v<version>.json` and `data/constraints/v<version>.txt`.

```sh
nix run path:.#prefetch-version -- 5.5.5
```

2. Add the exact release to `data/versions.nix`:

```nix
"5.5.5" = {
  srcHash = "sha256-...";
  constraintsPath = ./constraints/v5.5.5.txt;
  toolsJsonPath = ./tools/v5.5.5.json;
};
```

3. If this should become the new `v5` or `v6` target, update `latestByMajor` too:

```nix
latestByMajor."5" = "5.5.5";
```

4. Verify the exact release:

```sh
nix flake show path:. --all-systems
nix eval --impure --json --expr '
  let
    flake = builtins.getFlake (toString ./.);
  in
  builtins.attrNames (
    (flake.lib.mkEspIdfEnv {
      system = builtins.currentSystem;
      version = "5.5.5";
    }).packages
  )
'
nix develop --impure --expr '
  let
    flake = builtins.getFlake (toString ./.);
  in
  (flake.lib.mkEspIdfEnv {
    system = builtins.currentSystem;
    version = "5.5.5";
  }).devShells.full
' -c true
```

5. If you updated `latestByMajor`, verify the major alias too:

```sh
nix develop path:.#v5 -c true
```

## Notes

- `toolsJsonPath` and `constraintsPath` are relative to `data/versions.nix`, so use `./tools/...` and `./constraints/...`.
- Keep filenames aligned with the upstream tag: `data/tools/v<version>.json` and `data/constraints/v<version>.txt`.
- `v5` and `v6` are explicit aliases backed by `latestByMajor`.
- Use `mkEspIdfEnvFromUpstream` when you want dynamic version support without registering the version in `data/versions.nix`.
- `mkEspIdfEnvFromUpstream` still needs explicit upstream metadata, including `toolsJson`.
- Constraints are vendored because <https://dl.espressif.com/dl/esp-idf/espidf.constraints.v*.txt> is updated in place upstream; a pinned URL hash rots.
