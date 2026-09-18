# Wireguard Setup

Wireguard is the VPN we use to get network access to components in SWITCH cloud.
For added security, we only expose the Wireguard port (`51820`) to the public
internet. Once connected to the Wireguard tunnel, you will be in the same local
network as the VM and have access to all ports it exposes.

## Configuration

Wireguard is included in the nix shell, and the repository contains just recipes
to activate / deactivate the tunnel.

```
# Activate tunnel
just wg::quick vm-ordes-main up

# Deactivate tunnel
just wg::quick vm-ordes-main down
```

This dynamically decrypts the wireguard key in the repository and generates a
wireguard configuration for the component.

Alternatively install a [Wireguard client](https://www.wireguard.com/install/)
on your system and configure it globally. You can also configure it through a
graphical interface (e.g. NetworkManager on Linux). If you choose to configure
wireguard globally, be aware that you will need to update your configuration
when if keys are updated.

### Recommended Approach

```bash
just wg::quick <component> up
just wg::quick <component> down
```

to setup a network interface **to route all traffic on `10.10.50.1` through the
VPN to the VM's network**.

> [!NOTE]
>
> Throughout the repository, we use `10.10.50.1/32` as the Wireguard tunnel IP.
> It can be used for multiple machines as long as they live in independent
> networks.

**You can then run `just ssh-vm <component>` to reach the VM at `10.10.50.1`.**

### Wireguard Configuration File

The Wireguard configuration file used in `just wg::quick ...` if you need it
**for inspection only** can be shown with

```bash
client_private_key="..." # Your client's private key (default: `components/secrets/wireguard/client.prv.sops.bin`).
client_tunnel_index="0"  # Your client's index in the tunnel (starting from 0).
server_public_key="..."  # The server's public key (default: `components/secrets/wireguard/server.pub`).
server_ip="..."          # The VM's public IP.
comp="<component>"       # The component name.

nix eval --raw \
  "components/$comp/system/nixos#nixosConfigurations.$comp.config.settings.wireguard.showDefaultConfig" \
  --apply 'f: f {
    clientPrivKey = "'"$client_private_key"'";
    clientIdx = '"$client_tunnel_index"';
    serverPubKey = "'"$server_public_key"'";
    serverIP = "'"$server_ip"'";
  }'
```

> [!WARNING]
>
> You should not store this in any location also not in
> `/etc/wireguard/<component>.conf`. **Use the
> [recommended approach](#recommended-approach).**
