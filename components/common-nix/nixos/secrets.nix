{
  inputs,
  config,
  lib,
  ...
}:
{
  imports = [
    # inputs.agenix.nixosModules.default
    inputs.sops-nix.nixosModules.sops
  ];

  sops = {
    # The machine can decrypt `.sops` secrets in the /nix/store
    # with its host SSH keys.
    age.sshKeyPaths = lib.filter (p: lib.hasInfix "ed25519" p) (
      lib.map (x: x.path) config.services.openssh.hostKeys
    );

    # This will generate a new key if the key specified above does not exist
    age.generateKey = false;
  };
}
