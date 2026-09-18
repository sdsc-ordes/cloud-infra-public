# Virtual Machine `vm-ordes-main`

This component contains the shared ORDES development VM.

It consists of:

- `infra`: Infrastructure as code written in terraform.
- `system`: The declarative NixOS operating system.

External secrets and environment variables are declared in `deploy.yaml`. To
understand how secrets are loaded, look at the `secrets` component.

## Terinmal Sharing

We host a `upterm` server for pair-programming and terminal/command sharing.

```
just wg::quick vm-ordes-main up

upterm host --accept --server ssh://10.10.50.1:22223 \
  --force-command 'tmux attach -t pair-programming' -- \
  tmux new-session -As pair-programming
```

### TMate Server

This is simlar to `upterm` but older and should only be used as a backup.

We host a `tmate` server for terminal sharing under. Place a
`~/.config/tmate/sit-cloud-infra.conf` with

```tmux
set -g tmate-server-host "10.10.50.1"
set -g tmate-server-port 22222
set -g tmate-server-rsa-fingerprint     "SHA256:nrQKiQ5DCwax2zFbsZI6tCEB9Mgx8XavFR+xoHjiTC4"
set -g tmate-server-ed25519-fingerprint "SHA256:ReYZOKGZ5lUlEKLHuDJa4CAVQlQJXWxeEdxeBmMtV5I"
```

> [!NOTE]
>
> You can get the current fingerprints with
> `ssh-keyscan -q -t rsa,ed25519 -p 22222 10.10.50.1 | ssh-keygen -lf -`

### Usage

Start a session with

```bash
just wg::quick vm-ordes-main up
tmate -f ~/.config/tmate/sit-cloud-infra.conf
```
