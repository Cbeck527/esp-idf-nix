{
  description = "ESP-IDF v6 project";

  nixConfig = {
    extra-substituters = [ "https://esp-idf-nix.cachix.org" ];
    extra-trusted-public-keys = [
      "esp-idf-nix.cachix.org-1:6qHkAxmub00GqSujpkTqbL3XZvT6d4g8/13FcL+wrpQ="
    ];
  };

  inputs = {
    esp-idf-nix.url = "github:Cbeck527/esp-idf-nix";
  };

  outputs =
    {
      esp-idf-nix,
      ...
    }:
    {
      devShells = builtins.mapAttrs (_system: shells: { default = shells.v6; }) esp-idf-nix.devShells;
    };
}
