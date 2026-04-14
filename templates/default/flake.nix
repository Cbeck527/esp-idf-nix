{
  description = "ESP-IDF project";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    esp-idf-nix.url = "github:Cbeck527/esp-idf-nix";
  };

  outputs =
    {
      nixpkgs,
      esp-idf-nix,
      ...
    }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems =
        f:
        nixpkgs.lib.genAttrs supportedSystems (
          system: f { inherit system; pkgs = import nixpkgs { inherit system; }; }
        );
    in
    {
      devShells = forAllSystems (
        { system, ... }:
        let
          env = esp-idf-nix.lib.mkEspIdfEnv { inherit system; };
        in
        {
          default = env.devShells.full;
        }
      );
    };
}
