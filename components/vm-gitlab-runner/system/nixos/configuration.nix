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
    ./runner.nix

  ]
  ++ inputs.common-nix.nixosModules.all;

  system.stateVersion = "25.11";
}
