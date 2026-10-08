{
  inputs,
  ...
}:
{
  imports = [
    inputs.agenix.nixosModules.default
    ./disk-config.nix

    ./settings.nix
    ./secrets.nix
    ./cache.nix
    ./cache-write-user.nix

  ]
  ++ inputs.common-nix.nixosModules.minimal;

  system.stateVersion = "25.11";
}
