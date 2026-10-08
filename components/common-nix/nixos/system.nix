{
  inputs,
  config,
  ...
}:
{
  system.autoUpgrade = {
    enable = config.settings.autoUpgrade.enable;
    flake = inputs.self.outPath;
    flags = [
      "-L" # Print build logs.
      "--update-input"
    ]
    ++ config.settings.autoUpgrade.inputs
    ++ [
      "nixpkgs"
      "home-manager"
    ];
    dates = "02:00";
  };
}
