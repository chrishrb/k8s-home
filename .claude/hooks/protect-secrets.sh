#!/usr/bin/env bash
# PreToolUse hook: block direct edits to SOPS-encrypted files and local credentials.
set -o pipefail

command -v jq >/dev/null 2>&1 || exit 0

file_path=$(jq -r '.tool_input.file_path // .tool_input.notebook_path // empty')
[[ -z "${file_path}" ]] && exit 0

case "${file_path}" in
    *.sops.yaml | *.sops.yml)
        echo "Blocked: ${file_path} is SOPS-encrypted. Editing it in place breaks the MAC. Use 'sops edit ${file_path}' (run it yourself with '! sops edit ...'), or put the secret in Bitwarden and reference it from an ExternalSecret." >&2
        exit 2
        ;;
    */age.key | *.agekey | */kubeconfig | */talosconfig | */clusterconfig/*)
        echo "Blocked: ${file_path} holds local credentials or generated Talos config and must not be edited." >&2
        exit 2
        ;;
esac

exit 0
