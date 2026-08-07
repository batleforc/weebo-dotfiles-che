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

### Customise your VsCode IDE

- [Eclipse Che DOC](https://eclipse.dev/che/docs/stable/administration-guide/editor-configurations-for-microsoft-visual-studio-code/)

An exemple of this configuration (the one i use), can be found in this repo in the `config` folder. I deploy it with a kustomize app.

## Claude Code

### Share the Claude session across workspaces

No RWX PVC needed: generate a long-lived OAuth token once with
`claude setup-token` (valid ~1 year), then store it in an auto-mounted
Secret so every workspace gets it as an environment variable.

```yaml
kind: Secret
apiVersion: v1
metadata:
  name: claude-token
  namespace: dev-ws-max
  labels:
    controller.devfile.io/mount-to-devworkspace: 'true'
    controller.devfile.io/watch-secret: 'true'
  annotations:
    controller.devfile.io/mount-as: env
stringData:
  CLAUDE_CODE_OAUTH_TOKEN: sk-ant-oat01-REPLACE_ME
```

Claude Code picks up `CLAUDE_CODE_OAUTH_TOKEN` automatically, so no
`claude login` is needed in new workspaces. Don't mount
`~/.claude/.credentials.json` instead: Claude Code rewrites it on every
token refresh, so a read-only Secret copy goes stale almost immediately.

### Copy / Paste from the TUI

When the Claude Code TUI is running, it enables mouse mode so the terminal
hands mouse events to the app instead of doing its normal selection. Your usual
click-drag copy stops working as a result.

To copy text out of the TUI, use the terminal's native selection by holding
**Shift**:

1. Hold **Shift** and drag with the mouse to select the text.
2. **Keep Shift held down** and press **Ctrl+C** to copy.

Releasing Shift before the copy hands the mouse back to the app, so don't let go
until the text is on the clipboard.

To paste, use **Ctrl+V**. Avoid **Ctrl+Shift+V**: since the IDE runs in the
browser, that shortcut opens the Chrome DevTools instead of pasting.