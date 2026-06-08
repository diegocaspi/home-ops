provider "kubernetes" {
  config_path = "~/.kube/clusters/nova.yaml"
}

provider "helm" {
  kubernetes = {
    config_path = "~/.kube/clusters/nova.yaml"
  }
}
