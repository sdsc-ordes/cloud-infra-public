{
  inputs,
  ...
}:
{
  imports = [
    ./disk-config.nix

    ./settings.nix
    ./boot.nix
    ./secrets.nix

    ./tmate.nix
    ./upterm.nix
  ]
  ++ inputs.common-nix.nixosModules.minimal
  ++ [ inputs.common-nix.nixosModules.virtualization ];

  system.stateVersion = "25.11";
}
