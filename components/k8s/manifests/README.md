# FluxCD Manifests

Contains the manifests watched and deployed by flux operators on our different
kubernetes clusters.

## Structure

- `common` contains the base definition of what is deployed on clusters.
  - `common/apps` holds applications (helm charts and their namespace).
  - `common/operators` holds cluster-level infrastructure (operators, CRDs).
- `deployments` defines clusters-specific values and secrets.

## Cluster Definitions

The flux operator deployed on a cluster should be watching a cluster's `main/`
directory (e.g. `components/k8s/manifests/deployments/sck-sit-dev/main`). The
cluster definition uses `Kustomization` to include the resources and apps to be
deployed (typically from common). Each cluster defines their own secrets under
`<cluster-dir>/secrets`.

Each cluster defines a pipeline to enforce ordering of resources.

## Adding an App

1. Add your repository definition (source) as an `OCIRepository` in
   `common/apps/<app>/` if needed (e.g. for helm charts).
2. Add your manifests, or `HelmRelease` in the case of helm charts.
3. Include those manifests as resources in
   `deployments/<cluster>/main/pipeline/2-charts/kustomization.yaml`.
4. If relevant, create a kustomize patch for cluster-specific values. The patch
   should be in `deployments/<cluster>/main/pipeline/2-charts/<app>.yaml`
5. If relevant, define cluster-level secrets for your app in
   `deployments/<cluster>/secrets` and include them through kustomizations.

> [!IMPORTANT]
>
> When defining your `HelmRelease` in `common/app`, only inline values that will
> not be patched at cluster level. Those inline values always have maximum
> priority and will prevent overrides.

## Networking

This section describes how to expose your app to the public internet. We deploy
[traefik proxy](doc.traefik.io) as the ingress / networking operator on each
cluster. It supports three "providers":

- Ingress: Provider-agnostic legacy Kubernetes method (frozen API!).
- IngressRoute: Traefik-specific improvement over `Ingress`.
- Gateway: The new and **recommended** provider-agnostic Kubernetes method.

Please use the Gateway provider to expose your services. Ingress will be
deprecated soon.

### Example

Traefik creates a `GatewayClass` class named `traefik-gateway`. All you have to
do is create an `HTTPRoute` referring to that gateway and mapping hostnames +
rules to backend (services).

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: shrek-route
spec:
  parentRefs:
    - name: traefik-gateway
  hostnames:
    - "shrek.sck-sit-dev.dscompute.ch"
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: shrek-service
          port: 80
```

<details>
<summary>Full working example</summary>

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: debug-gateway

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: whoami
  namespace: debug-gateway
spec:
  replicas: 1
  selector: { matchLabels: { app: whoami } }
  template:
    metadata: { labels: { app: whoami } }
    spec:
      containers:
        - name: whoami
          image: traefik/whoami
          ports: [{ containerPort: 80 }]

---
apiVersion: v1
kind: Service
metadata:
  name: whoami
  namespace: debug-gateway
spec:
  selector: { app: whoami }
  ports: [{ port: 80, targetPort: 80 }]

---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: whoami
  namespace: debug-gateway
spec:
  parentRefs:
    - name: traefik-gateway
      namespace: traefik # gateway lives in another namespace
  hostnames:
    - "whoami.sck-sit-dev.dscompute.ch"
  rules:
    - matches:
        - path: { type: PathPrefix, value: / }
      backendRefs:
        - name: whoami
          port: 80
```

</details>

> [!NOTE]
>
> You will also need to add your hostname to the multi-host certificate of the
> cluster to get trusted https certificates. See for example
> [`.../sck-sit-dev/.../certificates.yaml`](/components/k8s/manifests/deployments/sck-sit-dev/main/pipeline/1b-certificates/certificates.yaml).

## Decryption

We use fluxCD's sops controller with age to decrypt secrets on the cluster side.
Each flux operator has a keypair whose public part are in the repository. When
encrypting cluster secrets, make sure that they are correctly encrypted for the
corresponding cluster key.

## Multiple instances of an app

> [!NOTE]
>
> Every app should be deployed only once per cluster, this documents a
> workaround in case this is not possible.

Kustomize matches patches on group/version/kind **+ name + namespace**, and a
patch cannot rename or move its target: `metadata.name` and `metadata.namespace`
are matching criteria. Renaming therefore goes through the `namespace` (or
`nameSuffix`) transformer.

Each instance gets its own directory under
`<cluster-dir>/pipeline/2-charts/<app>-<env>/` containing:

- `kustomization.yaml`: references the common app base, sets
  `namespace: <app>-<env>` (this also renames the base `Namespace` object) and
  points at the values patch.
- `values.yaml`: a `HelmRelease` patch keeping the base `metadata.name`, and
  overriding only the values that differ between instances.

`releaseName` stays the same across instances: helm release storage is
namespaced, so identical release names in different namespaces do not collide,
and every reference resolved inside the namespace (service names, database
hosts, TLS secrets) stays valid without renaming.
