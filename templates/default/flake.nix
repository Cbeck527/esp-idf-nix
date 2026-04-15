{
  description = "ESP-IDF project";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    esp-idf-nix = {
      url = "github:Cbeck527/esp-idf-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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
