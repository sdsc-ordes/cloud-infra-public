{ inputs, outputs, ... }:
let
  system = "x86_64-linux";
in
inputs.nixpkgs.lib.nixosSystem {
  inherit system;
  modules = [
    ./configuration.nix
  ];

  specialArgs = {
    inherit inputs outputs system;
  };
}
