{ nixpkgs-zed, ... }:
{
  config,
  osConfig,
  lib,
  pkgs,
  ...
}:
let
  inherit (pkgs) system;
  inherit (osConfig) settings;
  inherit (config.home) username;
  userSetting = settings.users.${config.home.username};

  enable = (username != "root" && userSetting.zedServer.enable);
in
{
  home.file.".zed_server" = lib.mkIf enable {
    source = "${nixpkgs-zed.legacyPackages.${system}.zed-editor.remote_server}/bin";
    recursive = true;
  };
}
