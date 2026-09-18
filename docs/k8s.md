# Kubernetes notes

The team kubernetes cluster is installed in the SWITCH Cloud organization using
their interactive wizard. It is not deployed using IaC and therefore not
declared in this repository. GitOps operators and other cluster configurations,
are managed with OpenTofu and are declared here.

## Deployment

To configure the cluster and the operators using IaC you will need to provide a
github `access token` with `administration` permissions for this (`cloud-infra`)
repository. The token will be used once by flux to request a `deploy-token`.

## Managing users

### Adding user

To let team members deploy to the kubernetes cluster, they should **not** be
added as members of the SWITCH Cloud organization.

Instead, they should be added as edit-users to the kubernetes cluster from the
kubernetes dashboard.

To navigate there from the SWITCH Cloud Project UI, go to the Kubernetes
service, Dashboard, then navigate to the cluster. At the bottom of the screen,
go to RBAC, select User (instead of ServiceAccount) in the dropdown menu, and
add a new binding.

To add a new user to the cluster, you can add a Cluster binding in edit-mode,
this will not allow them to create namespaces.

You can also give them full admin access to a specific namespace. It is
recommended to create a project namespace for the user and make them admin of
it.

> [!NOTE] The RBAC configuration is case-sensitive. If you granted access to a
> user and they still have no permission after downloading their kubeconfig
> file, make sure to validate that the email in the error message exactly
> matches the email you used for RBAC.

### Token management

As the user is not able to access the SWITCH UI (not an organization member),
you will need to send them the link to download their kubeconfig file.

Do **not** download the kubeconfig file yourself and send it to them, as this
would contain your secrets and/or refresh token.

Instead, click on the three dots on the top-right of your cluster page, and
click on `Share Cluster`. You can then select between a KKP and a OIDC
kubeconfig file. We recommend using OIDC because it provides stronger security.
Copy the link displayed on the page and send it to the user you want to give
access to. They should be able to use it to download their kubeconfig file.

> [!NOTE]
>
> If you selected the oidc-kubeconfig method, the user needs to install the
> [kubelogin oidc plugin](https://github.com/int128/kubelogin) on their machine.
