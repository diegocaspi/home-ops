{ pkgs, lib, config, inputs, ... }:

{
  packages = [
    pkgs.git

    #Kubernetes
    pkgs.holos

    # Encryption
    pkgs.sops pkgs.age

    # Talos
    pkgs.talosctl pkgs.talhelper

    # Infrastructure
    pkgs.terragrunt pkgs.opentofu
  ];

  dotenv.enable = true;
  languages = {
    cue.enable = true;
    opentofu.enable = true;
  };

  scripts = {
    talos-gen = {
      exec = "talhelper genconfig -c talos/talconfig.yaml -o talos/clusterconfig";
      description = "Generate Talos cluster configuration files";
    };

    talos-encrypt = {
      exec = "sops --config .sops.yaml -e -i talos/talsecret.sops.yaml";
      description = "Encrypt the talos secrets file using sops";
    };

    infra-plan = {
      exec = "terragrunt run --all plan";
      description = "Run terragrunt plan for all infrastructure modules";
    };

    infra-apply = {
      exec = "terragrunt run --all apply";
      description = "Run terragrunt apply for all infrastructure modules";
    };
  };
}
