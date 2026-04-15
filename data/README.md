# Adding an ESP-IDF Version

This directory holds the checked-in metadata for the flake's pure `mkEspIdfEnv` path.

Each supported release needs:

- a `tools.json` snapshot under `data/tools/`
- an exact entry in `data/versions.nix`

Major aliases are managed separately through `latestByMajor`.

## Workflow

1. Run the helper for the version you want to add.

```sh
nix run path:.#prefetch-version -- 5.5.5
```

2. Save the JSON part of the output to `data/tools/v5.5.5.json`.

3. Add the exact release to `data/versions.nix`:

```nix
"5.5.5" = {
  srcHash = "sha256-...";
  constraintsHash = "sha256-...";
  toolsJsonPath = ./tools/v5.5.5.json;
};
```

4. If this should become the new `v5` or `v6` target, update `latestByMajor` too:

```nix
latestByMajor."5" = "5.5.5";
```

5. Verify the exact release:

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

6. If you updated `latestByMajor`, verify the major alias too:

```sh
nix develop path:.#v5 -c true
```

## Notes

- `toolsJsonPath` is relative to `data/versions.nix`, so use `./tools/...`.
- Keep the filename aligned with the upstream tag: `data/tools/v<version>.json`.
- `v5` and `v6` are explicit aliases backed by `latestByMajor`.
- Use `mkEspIdfEnvFromUpstream` when you want dynamic version support without registering the version in `data/versions.nix`.
- `mkEspIdfEnvFromUpstream` still needs explicit upstream metadata, including `toolsJson`.
