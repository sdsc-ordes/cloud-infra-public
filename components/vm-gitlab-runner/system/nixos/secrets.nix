{ config, ... }:
let
  inherit (config.settings) secrets;
in
{
  sops.secrets.nix-cache-ssh-nix = {
    sopsFile = secrets.files.nix-cache-ssh-nix;
    format = "binary";
    mode = "600";
    owner = "ci";
    group = "users";
  };

  sops.secrets.nix-store-signing-key = {
    sopsFile = secrets.files.nix-store-signing-key;
    format = "binary";
    mode = "600";
    owner = "root";
    group = "root";
  };

  sops.secrets.gitlab-runner-custodian-token-config = {
    sopsFile = secrets.files.gitlab-runner-custodian-token-config;
    format = "dotenv";
    mode = "600";
    owner = "ci";
    group = "users";
  };

  sops.secrets.gitlab-runner-bpa-docs-token-config = {
    sopsFile = secrets.files.gitlab-runner-bpa-docs-token-config;
    format = "dotenv";
    mode = "600";
    owner = "ci";
    group = "users";
  };
}
