{ config, ... }:
let
  inherit (config.settings) secrets;
in
{
  # TODO: Add secrets etc...
  # age.secrets.blablabla = {
  #   file = secrets.files.signing-key;
  #   mode = "600";
  #   owner = "root";
  #   group = "root";
  # };
}
