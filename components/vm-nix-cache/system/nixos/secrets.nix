{ inputs, ... }:
let
  gitlab-runner-secrets = inputs.secrets.lib.vm-gitlab-runner;
in
{
  sops.secrets.signingKey = {
    sopsFile = gitlab-runner-secrets.files.nix-store-signing-key;
    format = "binary";
    mode = "600";
    owner = "root";
    group = "root";
  };
}
