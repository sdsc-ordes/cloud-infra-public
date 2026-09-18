{ self }:
{
  lib,
  inputs,
  outputs,
  config,
  ...
}:
let
  inherit (config) settings;
in
{
  imports = [
    inputs.home-manager.nixosModules.home-manager
  ];

  home-manager =
    let
      allUserNames = (lib.attrNames settings.users) ++ [ "root" ];

      userSettings = lib.genAttrs allUserNames (username: {
        home.username = username;
        imports = [
          # Import the exported home module.
          self.homeManagerModules.home
        ];
      });
    in
    {
      useGlobalPkgs = true;
      useUserPackages = true;
      users = userSettings;

      extraSpecialArgs = {
        inherit inputs outputs;
      };

      backupFileExtension = "backup";
    };
}
