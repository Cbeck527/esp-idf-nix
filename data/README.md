# Adding an ESP-IDF Version

This directory holds the checked-in metadata for the flake's pure `mkEspIdfEnv` path.

Each supported ESP-IDF version needs two things:

- a `tools.json` snapshot under `data/tools/`
- an entry in `data/versions.nix`

## Workflow

1. Run the helper for the version you want to add.

```sh
nix run .#prefetch-version -- 5.5.5
```

2. Save the JSON part of the output to `data/tools/v5.5.5.json`.

3. Add a matching entry to `data/versions.nix`:

```nix
"5.5.5" = {
  srcHash = "sha256-...";
  constraintsHash = "sha256-...";
  toolsJsonPath = ./tools/v5.5.5.json;
};
```

4. If this should become the default release, update `defaultVersion`.

5. Verify the new version:

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

## Notes

- `toolsJsonPath` is relative to `data/versions.nix`, so use `./tools/...`.
- Keep the filename aligned with the upstream tag: `data/tools/v<version>.json`.
- `nix develop .#full` only switches to the new version if you also update `defaultVersion`.
- Use `mkEspIdfEnvFromUpstream` only when you want dynamic version support without checking metadata into the repo.
