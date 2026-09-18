# Kubernetes

## GitOps setup

This component embeds our kubernetes infrastructure as code and gitops
configurations. It is split into `infra` and `manifests` directories.

`infra` bootstraps the flux operator on kubernetes clusters, while `manifests`
is consumed by the flux operator to deploy resources based on the state of the
repository.

The `manifests` layout is based on the
[flux monorepo](https://cloudogu.github.io/gitops-talks/2023-03-mastering-gitops/#/ex4/5)
pattern with conventions taken from the SDSC engineering team gitops repo.

## DNS

We have the following cluster-level DNS records managed by
support@datascience.ch:

- `*.sck-sit-dev.dscompute.ch` -> `86.119.84.181`
  - Goes to `traefik` ingress of `sck-sit-dev` cluster
- `*.sck-sit-prod.dscompute.ch` -> `86.119.86.7`
  - Goes to `traefik` ingress of `sck-sit-prod` cluster

This means you may deploy your apps / prototype on any subdomain of those, e.g.
`https://swamp.sck-sit-prod.dscompute.ch`. See
[manifests/README.md](/components/k8s/manifests/README.md) to learn how to
deploy your apps via gitops.
