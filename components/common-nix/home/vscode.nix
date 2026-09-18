{ vscode-server }:
{
  lib,
  config,
  osConfig,
  ...
}:
let
  inherit (osConfig) settings;
  inherit (config.home) username;
  userSetting = n: settings.users.${n};

  enable = (username != "root" && (userSetting username).vscodeServer.enable);
in
{
  imports = [
    vscode-server.homeModules.default
  ];

  services = lib.mkIf enable {
    vscode-server.enable = true;
  };
}
