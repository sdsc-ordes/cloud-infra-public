# Stub for the e2e tests (tests/e2e.nu): exposes only the attr paths the
# tooling evals; not a real NixOS system. Zero inputs -> offline eval.
{
  outputs = _: {
    nixosConfigurations.integration-test.config.settings.wireguard = {
      enable = false;
      tunnelIP = "10.100.99.9";
    };
  };
}
