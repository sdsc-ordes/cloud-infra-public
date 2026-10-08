# Enabling IPv6 Networking

## Key Ingredients

### Infra

The OpenStack router resource `openstack_networking_router_v2` needs a network
`openstack_networking_network_v2` with 2 `openstack_networking_subnet_v2`s for
[IPv4 and IPv6](../components/vm-gitlab-runner/infra/network.tf). The VM will
receive its global IPv6 address and default IPv6 route via Router Advertisements
from the OpenStack router's IPv6 subnet.

So the IPv6 prefix that the subnet on the router gets from the `public_ipv6`
pool is directly routable to the public internet, and there is no concept of
floating IPs for IPv6 in this setup.

If one does not request the IPv6 from that pool the subnet becomes a network
with ULA addresses (unique local addresses starting with `fe80:....` and then
Openstack would need to do network address translation (`NAT66`) as common in
IPv4 to make traffic routable to the internet. _Openstack doesn't support this
because `NAT66` is against the IPv6 design, its not needed_ the IPv6 from the
`public_ipv6` pools is directly routable to the internet.

### System

To enable IPv6 networking the NixOS must use the correct `network.conf` settings
in [`networking.nix`](../components/common-nix/nixos/networking.nix) for the
interface wildcard names `en*` and `eth*`.

The `Multicast = true;` and `LinkLocalAddressing = true` are crucial since
otherwise the kernel disables the
[router advertisement](https://www.man7.org/linux/man-pages/man5/systemd.network.5.html)

Without these, the kernel will ignore Router Advertisements (RA), preventing the
interface from getting a global IPv6 address:

- Router Advertisements (RA) are needed for the interface to get:
  - The subnet prefix (`2001:…/64`)
  - The default IPv6 gateway

The router (gateway) has a local IPv6 address (link-local address) when you do
`networkctl status enp3s0`:

```bash
Gateway: 10.20.0.1
         fe80::f816:3eff:feff:2ccb
```

- `fe80::/10` addresses are link-local IPv6 addresses.
- Every IPv6-enabled interface automatically gets one link-local address,
  derived from its MAC by default (EUI-64) or assigned manually.
- **This is the default IPv6 gateway for your VM, learned via Router
  Advertisement (RA) from the OpenStack router.**

1. Check current IPv6 addresses on the interface:

   ```bash
   ip -6 addr show enp3s0
   ```

   - Look for:
     - **link-local address**: `fe80::…` → always present
     - **global IPv6 address**: `2001:…/64` → assigned via RA/DHCPv6

     > [!IMPORTANT]
     >
     > This **global IPv6** is a **publicly** reachable address. So you need
     > IPv6 security rules on the VM to block complete access.

   - If you only see link-local addresses, the RA has **not been accepted** yet.
     Check `journalctl -u systemd-networkd.service` and you should see

     ```bash
     systemd-networkd[1410]: enp3s0: DHCPv6 address 2001:620:6:e0cf::325/128 (valid forever, pref>
     ```

2. Check the default IPv6 route with `ip -6 route show`:

   ```bash
   2001:620:6:e0cf::/64 dev enp3s0 proto ra metric 1024 pref medium
   fe80::/64 dev enp3s0 proto kernel metric 256 pref medium
   fe80::/64 dev podman0 proto kernel metric 256 pref medium
   fe80::/64 dev veth1 proto kernel metric 256 pref medium
   fe80::/64 dev veth0 proto kernel metric 256 pref medium
   default nhid 1439858043 via fe80::f816:3eff:feff:2ccb dev enp3s0 proto ra metric 1024 expires 65091sec pref medium
   ```

   - Should see something like:

   ```
   2001:620:6:e0cf::/64 dev enp3s0 proto ra metric 1024 pref medium
   fe80::/64 dev enp3s0 proto kernel metric 256 pref medium
   default via fe80::f816:3eff:fe1a:91b4 dev enp3s0 proto ra metric 1024 expires ...
   ```

   - `default via <link-local>` → default IPv6 gateway learned via RA
   - If `default` is missing → cannot reach outside IPv6 network

3. Check that RA is being received

   ```bash
   nix-shell -p tcpdump --command "tcpdump -i enp3s0 icmp6"
   ```

   - RA packets are **ICMPv6 type 134**
   - You should see output like:

     ```
     IP6 fe80::1 > ff02::1: ICMP6, router advertisement, length 64
     ```

### Summary

- `ip -6 addr` → shows addresses
- `ip -6 route` → shows default route
- `tcpdump` → shows RA arriving
- `sysctl net.ipv6.conf.enp3s0.accept_ra` → check RA processing
- `networkctl` / `journalctl` → check DHCPv6 and RA handling
- `ping -6` / `curl -v -6` → test actual connectivity
