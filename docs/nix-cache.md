# Nix Cache

<!--toc:start-->

- [Nix Cache](#nix-cache)
  - [NetRC Configuration](#netrc-configuration)
    - [File Format](#file-format)
    - [NixOS](#nixos)
    - [Other Linux Distributions](#other-linux-distributions)
    - [Verification](#verification)
    - [Troubleshooting](#troubleshooting)
    - [Upload the Check File](#upload-the-check-file)

<!--toc:end-->

Nix build times can be long and repetitive as we rebuild many times the same
things. This slows down CI and work on personal machines.

While packages from public repositories can be downloaded pre-built from
community cache servers, our own derivations (compiled programs, custom
devshells, ...) need to be rebuilt everytime.

This is because we have read-only access to public cache servers. Our team
cache-server solves this issue by giving us read-write access: when one team
member (or CI) builds one custom derivation, it is uploaded to the cache server,
and all other team members can download it directly without rebuilding.

## Configuring

To configure our Nix cache you **need**

- [**a netrc file configured**](#netrc-configuration) for you Nix daemon and
- in the `flake.nix`s where you want to use it

  ```nix
  {
    nixConfig = {
      extra-substituters = [
        "https://nix-cache.sck-sit-dev.dscompute.ch"
      ];
      extra-trusted-public-keys = [
        "nix-cache:lVTYyJ3CTjHRnuhxA5APy9jrdZGdfyuxKOwU7lKihZE="
      ];
    };

    # Rest of flake.
  }
  ```

- optionally you can also globally configure the cache by setting the above
  settings in the global Nix config `/etc/nix/nix.conf`. See
  [#netrc-configuration].

## NetRC Configuration

The cache is behind HTTP basic auth at the ingress. A Nix substituter can only
present credentials through `netrc`, so the password has to live in a file the
Nix daemon can read. Decrypt the secret here
[`nix-cache`](../components/secrets/k8s/sck-sit-dev/niks3-basicauth.sops.yaml).

### File Format

```text
machine nix-cache.sck-sit-dev.dscompute.ch
login nixcache
password <password>
```

The daemon performs all substitution, so **a `~/.netrc` in your home directory
is never consulted**. The file must be owned by `root` with mode `0400`.

### NixOS

Point `netrc-file` at a path outside the Nix store. Anything interpolated into a
NixOS option is copied to `/nix/store`, which is world readable, so
`environment.etc."nix/netrc".text` would publish the password to every user on
the machine.

With `sops-nix`:

```nix
{ config, ... }:
{
  sops.secrets.nix-netrc = {
    owner = "root";
    group = "root";
    mode = "0400";
  };

  nix.settings.netrc-file = config.sops.secrets.nix-netrc.path;
}
```

Without a secret manager, write the file out of band and reference it by path:

```nix
{
  nix.settings.netrc-file = "/etc/nix/netrc";
}
```

### Other Linux Distributions

Write the file:

```bash
sudo install -m 0400 -o root -g root /dev/stdin /etc/nix/netrc <<'NETRC'
machine nix-cache.sck-sit-dev.dscompute.ch
login <user>
password <password>
NETRC
```

Add to `/etc/nix/nix.conf`:

```text
netrc-file = /etc/nix/netrc
```

Restart the daemon. Nix reads its configuration once at process start, so an
edit alone has no effect:

```bash
sudo systemctl restart nix-daemon
```

### Verification

```bash
nix-store --realise \
  --substituters https://nix-cache.sck-sit-dev.dscompute.ch \
  --trusted-public-keys nix-cache:lVTYyJ3CTjHRnuhxA5APy9jrdZGdfyuxKOwU7lKihZE= \
  /nix/store/hmpax932mcbdyyxpfigb97a69s4fgpi1-check-that-cache-works.md -v
```

The output names the substituter it used:

```text
copying path '/nix/store/...' from 'https://nix-cache.sck-sit-dev.dscompute.ch'...
```

Confirm the setting is live, then confirm the credential works as the user that
actually reads it:

```bash
netrcFile=$(nix config show | grep netrc-file | sed 's/.*=//')
curl --netrc-file "$netrcFile" \
  https://nix-cache.sck-sit-dev.dscompute.ch/nix-cache-info
```

Output:

```
StoreDir: /nix/store
WantMassQuery: 1
Priority: 30
```

### Troubleshooting

- `file '...' does not exist in binary cache`: Nix reports `401` and `403`
  identically to a missing object. Verify the credential before concluding the
  path is absent.
- `nix ... --option netrc-file ...` and `nixConfig` in a `flake.nix` are ignored
  by the daemon unless you are listed in `nix.settings.trusted-users`. Only
  `/etc/nix/nix.conf` is authoritative.
- Nix caches cache lookups, negative results included, for
  `narinfo-cache-negative-ttl` (one hour by default). Clear stale entries with
  `rm -f ~/.cache/nix/binary-cache-*`.
- A missing entry in `trusted-public-keys` makes the daemon skip the path and
  build from source instead of reporting an error.

## Usage in CI

You need `niks3` as in this `flake.nix` to push with the
[API token configured here](../components/k8s/manifests/deployments/sck-sit-dev/secrets/niks3-secrets.sops.yaml).

```shell
niks3 push \
--auth-token-path "$TOKEN_PATH" \
--server-url "https://nix-cache.sck-sit-dev.dscompute.ch" \
/nix/store/....
```
