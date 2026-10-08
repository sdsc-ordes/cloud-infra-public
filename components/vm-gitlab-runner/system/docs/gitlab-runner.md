# Gitlab-Runner

The general deployment is described in the [README.md](./../README.md). This
document gives some more information about the maintenance of the Gitlab Runner.

## Maintenance

All recipes here refer to the [`justfile`](../hosts/gitlab-runner/justfile).

### Status

To print a common status about the system run

```shell
just vm::status
```

### Visualizing Performance

On the VM do:

```shell
btop
```

### Updating VM Podman Images

When you update any of the `local/*` images in `runner.nix`. You need to

- Run `just podman-flush-job-images` before `just deploy` because we need to
  flush all job images.

- Run `DEPLOY_RS_ARGS=--boot just deploy vm-gitlab-runner`.

- Run `reboot` the VM.

  The `update-nix-daemon-store.service` should take care of copying all missing
  new Nix store paths to the maybe already existing `nix-daemon-store` volume
  **before `podman-nix-daemon-container.service` and `gitlab-runner.service`**
  start.

### VM's Nix Store Maintenance

The NixOS `/nix/store` of the VM can be simply garbage-collected with

```shell
just vm::gc
```

### Quickflush to Regain Space

Stop the runners and daemons and flush all volumes, then you reboot.

```just
just vm::podman-flush-all
```

> [!NOTE]
>
> **When you reboot all stuff gets recreated and runs again with new space!**
> The runner connects itself again.

### Podman Normal Maintenance

This will just garbage collect stuff:

```shell
just vm::podman-gc
```

### Prune Podman Images

The CI might add more images than the `local/nix-daemon` and `local/alpine` (or
`local/nix`), you can clean them with stopping all containers (**note: this
stops jobs**)

```shell
just vm::podman-gc-images
```

It will only delete images which do not have `no-prune` label (e.g it will not
prune `local/nix-daemon`, `local/alpine` or `local/nix` etc.).

### Prune Podman Volumes

The VM runs a container `nix-daemon-container` which runs the `nix daemon` which
manages the `/nix/store` and it has 3 volumes attached:

- `nix-daemon-store`: **Contains the shared `/nix/store` which each job will
  mount `read-only`**.

  > [!TIP]
  >
  > This volume can grow quite significantly.

- `nix-daemon-socket`: Contains the Nix socket which each job will mount, to
  communicate to the Nix daemon and be able to store stuff into the `/nix/store`
  (it is only **read-only**).

- `nix-daemon-db`: The Nix database which is accompanied with the store.

- `podman-cache`: The container cache of the podman daemon the job containers
  use.

## Debugging CI Jobs

TODO
