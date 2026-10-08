# Own settings to build the NixOS configurations.
{
  inputs,
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib) mkOption mkEnableOption types;
  cfg = config.settings; # The evaluated settings we define below.
  mkWireguardConfig =
    {
      tunnelIP,
      clientPrivKey,
      clientIdx,
      serverPubKey,
      serverIP,
    }:

    let
      prefix = lib.concatStringsSep "." (lib.sublist 0 3 (lib.splitString "." tunnelIP));

      clientIP = "${prefix}.${toString (clientIdx + 2)}";
    in
    ''
      [Interface]
      Address = ${clientIP}/32
      PrivateKey = ${clientPrivKey}

      [Peer]
      PublicKey = ${serverPubKey}
      Endpoint = ${serverIP}:51820
      AllowedIPs = ${tunnelIP}/32
      PersistentKeepalive = 25
    '';
in
{
  # Some option declarations which can be used to specify
  # in `config.settings.???`
  options = {
    settings = {
      users = mkOption {
        description = "User accounts managed by this module (not root).";
        default = { };

        type = types.attrsOf (
          types.submodule (
            { name, ... }:
            {
              options = {
                name = mkOption {
                  description = "The user name.";
                  default = name;
                  type = types.str;
                };

                sshKeys = mkOption {
                  description = "All keys which have access over SSH to this user account.";
                  default = [ ];
                  type = types.listOf types.str;
                };

                vscodeServer = {
                  enable = mkEnableOption {
                    description = ''
                      If we enable `nix-community/nixos-vscode-server` to
                      fix the 'Remote-SSH' extension on connect for all users.
                    '';
                  };

                  extraRuntimeDependencies = mkOption {
                    type = types.listOf types.package;
                    default = [ ];
                  };
                };

                zedServer = {
                  enable = mkEnableOption {
                    description = "If the zed-server binary should be enabled for all users.";
                  };
                };
              };
            }
          )
        );
      };

      # The root user.
      root = {
        name = "root";

        sshKeys = mkOption {
          description = "All keys which have access over SSH to root account.";
          default = [ ];
          type = types.listOf types.str;
        };
      };

      autoUpgrade = {
        enable = mkEnableOption {
          description = "If the system does an auto upgrade over its own flake.";
          default = false;
        };

        inputs = mkOption {
          type = types.listOf types.str;
          description = ''
            Which inputs are auto upgraded additionally
            to `nixpkgs`, `home-manager`.
          '';
          default = [ ];
        };
      };

      ssh = {
        enable = mkEnableOption {
          description = "If SSH access is enabled. Used to override for a special init OS with SSH.";
          default = false;
        };
      };

      wireguard = {
        enable = mkEnableOption {
          description = "If wireguard is activated.";
          default = true;
        };

        tunnelIP = mkOption {
          description = "The IP of the wireguard tunnel on the network interface.";
          default = "10.10.50.1";
        };

        peers = {
          users = mkOption {
            description = ''
              The user names in the `config.toml` which must
              have a 'wireguard-public-key' field.
            '';
            type = types.listOf types.str;
            default = [ ];
          };
        };

        showDefaultConfig = mkOption {
          description = ''
            Pure function returning the default wireguard config.

            Arguments (attrset):
              1. client private key
              2. client tunnel index (starting at 0)
              3. server public key
              4. server public IP
          '';

          type = types.nullOr (types.functionTo types.str);

          readOnly = true;

          default =
            if cfg.wireguard.enable then
              args:
              mkWireguardConfig (
                args
                // {
                  inherit (cfg.wireguard) tunnelIP;
                }
              )
            else
              null;
        };
      };

      timezone = mkOption {
        description = "The timezone to use.";
        default = "Europe/Zurich";
        type = types.str;
      };

      hostName = mkOption {
        description = "The hostname.";
        default = "vm";
        type = types.str;
      };

      extraZshrc = mkOption {
        description = "Extra script (ZSH) to execute when entering the shell.";
        default = "";
        type = types.str;
      };

      secrets = mkOption {
        description = "The loaded secrets from the secrets component.";
        type = types.raw;
        readOnly = true;
      };
    };
  };

  config = {
    # Import the secrets from the secrets component.
    # Import wireguard conditionally.
    settings.secrets = inputs.secrets.lib.${cfg.hostName} // {
      wireguard = (lib.optionalAttrs cfg.wireguard.enable inputs.secrets.lib.wireguard);
    };
  };
}
