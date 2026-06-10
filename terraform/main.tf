terraform {
  required_version = ">= 1.11"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
  }
}

locals {
  ghcr_auth_dockerconfigjson = jsonencode({
    auths = {
      "ghcr.io" = {
        username = "diegocaspi"
        password = var.oci_token
        auth     = base64encode("diegocaspi:${var.oci_token}")
      }
    }
  })

  external_secrets_namespace_yaml = <<-YAML
    apiVersion: v1
    kind: Namespace
    metadata:
      name: external-secrets
  YAML

  onepassword_connect_token_secret_yaml = <<-YAML
    apiVersion: v1
    kind: Secret
    metadata:
      name: onepassword-connect-token
      namespace: external-secrets
    type: Opaque
    stringData:
      token: '${replace(var.onepassword_token, "'", "''")}'
  YAML
}

module "flux_operator_bootstrap" {
  source   = "controlplaneio-fluxcd/flux-operator-bootstrap/kubernetes"
  revision = var.bootstrap_revision

  common_metadata = {
    labels = {
      "pod-security.kubernetes.io/enforce" = "privileged"
      "pod-security.kubernetes.io/audit"   = "baseline"
      "pod-security.kubernetes.io/warn"    = "baseline"
    }
  }

  job = {
    host_network = true
    tolerations = [
      {
        operator = "Exists"
      },
    ]
  }

  gitops_resources = {
    instance_yaml = file("${path.root}/../kubernetes/clusters/${var.cluster_name}/flux-system/flux-instance.yaml")
    operator_chart = {
      values_yaml = file("${path.root}/../kubernetes/clusters/${var.cluster_name}/flux-system/flux-operator-values.yaml")
    }
    prerequisites = {
      yamls = [
        local.external_secrets_namespace_yaml,
        local.onepassword_connect_token_secret_yaml
      ]
      charts = [
        {
          name        = "cilium",
          repository  = "quay.io/cilium/charts/cilium",
          namespace   = "kube-system",
          values_yaml = file("${path.root}/../kubernetes/infrastructure/kube-system/controllers/${var.cluster_name}/cilium.values.yaml")
        },
      ]
    }
  }

  managed_resources = {
    secrets_yaml = <<-YAML
      apiVersion: v1
      kind: Secret
      metadata:
        name: ghcr-auth
      type: kubernetes.io/dockerconfigjson
      stringData:
        .dockerconfigjson: '${replace(local.ghcr_auth_dockerconfigjson, "'", "''")}'
    YAML
    runtime_info = {
      data = {
        CLUSTER_REGION = var.cluster_region
      }
    }
  }
}
