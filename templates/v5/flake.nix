{
  description = "ESP-IDF v5 project";

  nixConfig = {
    extra-substituters = [ "https://esp-idf-nix.cachix.org" ];
    extra-trusted-public-keys = [
      "esp-idf-nix.cachix.org-1:6qHkAxmub00GqSujpkTqbL3XZvT6d4g8/13FcL+wrpQ="
    ];
  };

  inputs = {
    esp-idf-nix.url = "github:Cbeck527/esp-idf-nix";
    nixpkgs.follows = "esp-idf-nix/nixpkgs";
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
            major = "5";
          };
        in
        {
          default = env.devShells.full;
        }
      );
    };
}
