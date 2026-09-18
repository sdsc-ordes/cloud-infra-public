# Run OpenTofu/Terraform operations, driven from `just tofu::<recipe>`.
use lib/common.nu *
use sops.nu component-env

const COMP = "k8s"

def --wrapped "main deploy-army-knife" [namespace: string = "default", ...rest: string] {
    let comp = load-component $COMP ...$rest

    let pod = $"
    apiVersion: v1
    kind: Pod
    metadata:
      name: swiss-army-knife
      labels:
        app: swiss-army-knife
      namespace: ($namespace)
    spec:
      containers:
        - name: swiss-army-knife
          image: nixery.dev/shell/bash/coreutils/findutils/dig/curl/wget/jq/yq/git/dnsutils/vim/awscli/inetutils
          command: [\"/bin/sleep\", \"3650d\"]
          imagePullPolicy: IfNotPresent
      restartPolicy: Always
    "

    log info $"Deploying swiss army knife to '($namespace)."

    $pod | ^kubectl apply -n $namespace -f -
}

def --wrapped "main kubectl" [...args: string] {
    let comp = load-component $COMP ...$args
    kubectl $comp ...$comp.tool_args
}

export def --wrapped kubectl [comp: record, ...args: string] {
    ^kubectl --kubeconfig $comp.kubeconfig ...$args
}

def --wrapped "main flux9s" [...args: string] {
    let comp = load-component $COMP ...$args
    ^flux9s --kubeconfig $comp.kubeconfig ...$comp.tool_args
}

def --wrapped "main k9s" [...args: string] {
    let comp = load-component $COMP ...$args
    ^k9s --kubeconfig $comp.kubeconfig ...$comp.tool_args
}

# Work with the project's Nix flake.
def main [] { }
