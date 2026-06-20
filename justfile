mod talos
mod terraform

repo := justfile_directory()

# List available recipes
default:
    @just --list

# Deploy Flux Operator on the image update automation Kubernetes cluster
bootstrap-update github_token=env_var('GITHUB_TOKEN') gh_update_token=env_var('GH_UPDATE_TOKEN'):
    @helm install flux-operator oci://ghcr.io/controlplaneio-fluxcd/charts/flux-operator \
      --namespace flux-system \
      --create-namespace \
      --set multitenancy.enabled=true \
      --wait

    @kubectl -n flux-system create secret docker-registry ghcr-auth \
      --docker-server=ghcr.io \
      --docker-username=flux \
      --docker-password="{{ github_token }}"

    @kubectl -n flux-system create secret generic github-auth \
      --from-literal=username=flux \
      --from-literal=password="{{ gh_update_token }}"

    @kubectl apply -f "{{ repo }}/kubernetes/clusters/update/flux-system/flux-instance.yaml"

    @kubectl -n flux-system wait fluxinstance/flux --for=condition=Ready --timeout=5m
