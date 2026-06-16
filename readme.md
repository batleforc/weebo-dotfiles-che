# DotFiles dedicated to eclipse che env

## Goal

The goal of this repo is to integrate [chezmoi](https://www.chezmoi.io/) inside of [Eclipse che](https://eclipse.dev/che).

## Setup

### Manifest to apply

```yaml
kind: ConfigMap
apiVersion: v1
metadata:
  name: env-var
  namespace: dev-ws-max
  labels:
    controller.devfile.io/mount-to-devworkspace: 'true'
    controller.devfile.io/watch-configmap: 'true'
  annotations:
    controller.devfile.io/mount-as: env
data:
  CHEZMOI_URL: https://github.com/batleforc/weebo-dotfiles-che.git
```

### Base Image

Base image can be found in the repo [WeeboDevImage](https://github.com/batleforc/WeeboDevImage/tree/main/che-min-mise).

### Start the workspace

[Go to Eclipse Che](https://cde.batleforc.fr#https://github.com/batleforc/weebo-dotfiles-che.git)

[Go to Redhat DevSpaces Sandbox](https://workspaces.openshift.com/#https://github.com/batleforc/weebo-dotfiles-che.git)
