{
  inputs,
  pkgs,
  ...
}:
let
  # Configure formatter.
  treefmtEval = inputs.treefmt-nix.lib.evalModule pkgs {
    projectRootFile = ".git/config";
    settings.global.excludes = [ "external/*" ];

    # Markdown, JSON, YAML, etc.
    programs.prettier.enable = true;

    # Terraform / HCL.
    programs.terraform.enable = true;

    # Toml
    programs.taplo.enable = true;

    # Shell.
    programs.shfmt = {
      enable = true;
      indent_size = 4;
    };

    programs.shellcheck.enable = true;
    settings.formatter.shellcheck = {
      options = [
        "-e"
        "SC1091"
      ];
    };

    # Nix.
    programs.nixfmt.enable = true;

    # Nushell
    settings.formatter.nushell = {
      command = "nufmt";
      includes = [ "*.nu" ];
    };
  };

  treefmt = treefmtEval.config.build.wrapper;
in
treefmt
