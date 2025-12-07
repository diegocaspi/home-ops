{ pkgs, lib, config, inputs, ... }:

{
  packages = [
    pkgs.git pkgs.yq

    #Kubernetes
    pkgs.helmfile

    # Encryption
    pkgs.sops pkgs.age

    # Talos
    pkgs.talosctl pkgs.talhelper

    # Infrastructure
    pkgs.terragrunt pkgs.opentofu
  ];

  dotenv.enable = true;
  languages = {
    opentofu.enable = true;
  };

  scripts = {
    talos-gen = {
      exec = "talhelper genconfig -c talos/talconfig.yaml -o talos/clusterconfig -s talos/talsecret.sops.yaml";
      description = "Generate Talos cluster configuration files";
    };

    talos-encrypt = {
      exec = "sops --config .sops.yaml -e -i talos/talsecret.sops.yaml";
      description = "Encrypt the talos secrets file using sops";
    };

    talos-apply = {
      exec = "./talos/apply.sh talos/talconfig.yaml";
      description = "Apply Talos configuration to the cluster nodes";
    };

    infra-plan = {
      exec = "terragrunt run --all plan --log-level trace";
      description = "Run terragrunt plan for all infrastructure modules";
    };

    infra-apply = {
      exec = "terragrunt run --all apply";
      description = "Run terragrunt apply for all infrastructure modules";
    };

    boot-crds = {
      exec = "helmfile -f bootstrap/helmfile.crds.yaml template -q | \
        yq 'select(.kind == \"CustomResourceDefinition\")' | \
        kubectl apply --server-side --field-manager bootstrap --force-conflicts -f -";
      description = "Install the CRDs needed to bootstrap the kubernetes cluster using helmfile";
    };

    boot-apps = {
      exec = "helmfile -f bootstrap/helmfile.apps.yaml sync --hide-notes --kube-context nova";
      description = "Bootstrap the kubernetes cluster using helmfile";
    };
  };

  enterShell = ''
      echo
      echo 🦾 Helper scripts you can run to make your development richer:
      echo 🦾
      ${pkgs.gnused}/bin/sed -e 's| |••|g' -e 's|=| |' <<EOF | ${pkgs.util-linuxMinimal}/bin/column -t | ${pkgs.gnused}/bin/sed -e 's|^|🦾 |' -e 's|••| |g'
      ${lib.generators.toKeyValue {} (lib.mapAttrs (name: value: value.description) config.scripts)}
      EOF
      echo
    '';
}
