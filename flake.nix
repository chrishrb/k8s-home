{
  description = "k8s-home";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    talhelper.url = "github:budimanjojo/talhelper";
  };
  outputs =
    { nixpkgs, ... }@inputs:
    inputs.flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        talhelper = inputs.talhelper.packages.${system}.default;
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            age
            direnv
            fluxcd
            go-task
            kubernetes-helm
            helmfile
            jq
            kubeconform
            kustomize
            minijinja
            talosctl
            sops
            stern
            kubectl
            kubectx
            talhelper
            yq
            python312

            makejinja
            python312Packages.email-validator
            python312Packages.netaddr
          ];
        };
      }
    );
}
