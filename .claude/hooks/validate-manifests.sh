#!/usr/bin/env bash
# PostToolUse hook: build the nearest kustomization of an edited manifest and validate it
# with kubeconform, using the same arguments as scripts/kubeconform.sh.
set -o pipefail

command -v jq >/dev/null 2>&1 || exit 0
command -v kustomize >/dev/null 2>&1 || exit 0
command -v kubeconform >/dev/null 2>&1 || exit 0

file_path=$(jq -r '.tool_input.file_path // empty')
[[ -z "${file_path}" ]] && exit 0

root="${CLAUDE_PROJECT_DIR:-$(pwd)}"
case "${file_path}" in
    "${root}"/kubernetes/apps/*.yaml | "${root}"/kubernetes/flux/*.yaml | "${root}"/kubernetes/tmpl/*.yaml) ;;
    *) exit 0 ;;
esac
[[ "${file_path}" == *.sops.yaml ]] && exit 0

# Walk up to the nearest directory with a kustomization.yaml (stop at kubernetes/).
dir=$(dirname "${file_path}")
while [[ "${dir}" != "${root}/kubernetes" && "${dir}" != "/" ]]; do
    [[ -f "${dir}/kustomization.yaml" ]] && break
    dir=$(dirname "${dir}")
done
[[ -f "${dir}/kustomization.yaml" ]] || exit 0

kubeconform_args=(
    "-strict"
    "-ignore-missing-schemas"
    "-skip" "Secret,ExternalSecret,ReplicationSource,ReplicationDestination"
    "-schema-location" "default"
    "-schema-location" "https://kubernetes-schemas.pages.dev/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json"
    "-summary"
)

if ! build=$(kustomize build "${dir}" --load-restrictor=LoadRestrictionsNone 2>&1); then
    echo "kustomize build failed for ${dir#"${root}"/}:" >&2
    echo "${build}" >&2
    exit 2
fi

# Substitute the plaintext cluster settings like Flux does (see scripts/kubeconform.sh).
settings_file="${root}/kubernetes/flux/vars/cluster-settings.yaml"
if [[ -f "${settings_file}" ]] && command -v yq >/dev/null 2>&1; then
    build=$(sed -e "$(yq -r '.data | to_entries | map("s|\\${" + .key + "}|" + .value + "|g") | join(";")' "${settings_file}")" <<<"${build}")
fi

if ! result=$(kubeconform "${kubeconform_args[@]}" <<<"${build}" 2>&1); then
    echo "kubeconform failed for ${dir#"${root}"/}:" >&2
    echo "${result}" >&2
    exit 2
fi

exit 0
