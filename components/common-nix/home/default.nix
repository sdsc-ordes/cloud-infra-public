{ self }:
{
  # We only export this combined module.
  home = import ./home.nix { inherit self; };
}
