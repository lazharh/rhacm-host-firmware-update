#!/usr/bin/env bash
# Copy this project to $HOME/gitrepos/github/ and scrub cleartext passwords
# in the destination only (source vars keep real secrets for lab use).
#
# Usage:
#   ./sync-to-gitrepos.sh
#   DEST_DIR=/path/to/other ./sync-to-gitrepos.sh

set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST_DIR="${DEST_DIR:-${HOME}/gitrepos/github/rhacm-host-firmware-update}"

if [[ ! -d "${HOME}/gitrepos/github" && "${DEST_DIR}" == "${HOME}/gitrepos/github/"* ]]; then
  echo "ERROR: ${HOME}/gitrepos/github does not exist. Create it or set DEST_DIR." >&2
  exit 1
fi

if [[ "${DEST_DIR}" == "${SRC_DIR}" || "${DEST_DIR}" == "${SRC_DIR}/"* ]]; then
  echo "ERROR: DEST_DIR must not be the source tree: ${DEST_DIR}" >&2
  exit 1
fi

echo "Syncing:"
echo "  from: ${SRC_DIR}"
echo "  to:   ${DEST_DIR}"

mkdir -p "${DEST_DIR}"

# No --delete: update/add the same project files, keep dest-only files
# (README, LICENSE, CI, notes, .git, etc.).
rsync -a \
  --exclude '.git/' \
  --exclude '.gitignore' \
  --exclude '__pycache__/' \
  --exclude '*.pyc' \
  --exclude '.vault_pass' \
  --exclude '*.retry' \
  "${SRC_DIR}/" "${DEST_DIR}/"

# Scrub lab-specific values in destination vars YAML.
# Leaves Jinja references like password: "{{ hub_password }}" untouched.
# Skips commented lines (leading #).
scrub_vars_file() {
  local f="$1"
  [[ -f "${f}" ]] || return 0
  local tmp
  tmp="$(mktemp)"
  sed -E \
    -e 's/^([[:space:]]*hub_password:[[:space:]]*).+$/\1""/' \
    -e 's/^([[:space:]]*spoke_password:[[:space:]]*).+$/\1""/' \
    -e 's/^([[:space:]]*password:[[:space:]]*)"[^{"]*"/\1""/' \
    -e "s/^([[:space:]]*password:[[:space:]]*)'[^{']*'/\1''/" \
    -e 's/^([[:space:]]*hub_username:[[:space:]]*).+$/\1"your_username"/' \
    -e 's/^([[:space:]]*spoke_username:[[:space:]]*).+$/\1"your_username"/' \
    -e 's/^([[:space:]]*username:[[:space:]]*)"[^{"]*"/\1"your_username"/' \
    -e "s/^([[:space:]]*username:[[:space:]]*)'[^{']*'/\1'your_username'/" \
    -e 's/^([[:space:]]*hub_api_url:[[:space:]]*).+$/\1"https:\/\/api.your-hub.example.com:6443"/' \
    -e 's/^([[:space:]]*spoke_api_url:[[:space:]]*).+$/\1"https:\/\/api.your-spoke.example.com:6443"/' \
    -e 's/^([[:space:]]*api_url:[[:space:]]*).+$/\1"https:\/\/api.your-spoke.example.com:6443"/' \
    -e 's/^([[:space:]]*cluster_namespace:[[:space:]]*).+$/\1your-cluster-namespace/' \
    -e 's/^([[:space:]]*-[[:space:]]*namespace:[[:space:]]*).+$/\1your-cluster-namespace/' \
    -e 's/^([[:space:]]*namespace:[[:space:]]*).+$/\1your-cluster-namespace/' \
    -e 's/^([[:space:]]*(-[[:space:]]*)?bmh_name:[[:space:]]*).+$/\1master-0.your-spoke.example.com/' \
    -e 's/^([[:space:]]*(-[[:space:]]*)?spoke_node_name:[[:space:]]*).+$/\1master-0.your-spoke.example.com/' \
    -e 's/^([[:space:]]*bios_firmware_url:[[:space:]]*).+$/\1"https:\/\/your-firmware-server.example.com\/path\/to\/bios"/' \
    -e 's/^([[:space:]]*bmc_firmware_url:[[:space:]]*).+$/\1"https:\/\/your-firmware-server.example.com\/path\/to\/bmc"/' \
    "${f}" > "${tmp}"
  mv "${tmp}" "${f}"
  echo "  scrubbed vars: ${f#${DEST_DIR}/}"
}

# Password-only scrub for role defaults (keep empty firmware URL defaults).
scrub_passwords_only() {
  local f="$1"
  [[ -f "${f}" ]] || return 0
  local tmp
  tmp="$(mktemp)"
  sed -E \
    -e 's/^([[:space:]]*hub_password:[[:space:]]*).+$/\1""/' \
    -e 's/^([[:space:]]*spoke_password:[[:space:]]*).+$/\1""/' \
    -e 's/^([[:space:]]*password:[[:space:]]*)"[^{"]*"/\1""/' \
    -e "s/^([[:space:]]*password:[[:space:]]*)'[^{']*'/\1''/" \
    "${f}" > "${tmp}"
  mv "${tmp}" "${f}"
  echo "  scrubbed passwords: ${f#${DEST_DIR}/}"
}

# Sanitize local paths / usernames in ansible.cfg (destination only).
scrub_ansible_cfg() {
  local f="${DEST_DIR}/ansible.cfg"
  [[ -f "${f}" ]] || return 0
  local tmp
  tmp="$(mktemp)"
  # remote_user=<login> -> your_username
  # /home/<login>/... -> $HOME/...
  sed -E \
    -e 's/^(remote_user=).+$/\1your_username/' \
    -e "s|${HOME}|\$HOME|g" \
    -e 's|/home/[^/:[:space:]]+|\$HOME|g' \
    "${f}" > "${tmp}"
  mv "${tmp}" "${f}"
  echo "  scrubbed ansible.cfg: remote_user -> your_username, home paths -> \$HOME"
}

echo "Scrubbing secrets / local paths in destination..."
shopt -s nullglob
for f in "${DEST_DIR}"/vars/*.yml "${DEST_DIR}"/vars/*.yaml; do
  scrub_vars_file "${f}"
done
for f in \
  "${DEST_DIR}"/roles/*/defaults/main.yml \
  "${DEST_DIR}"/roles/*/defaults/main.yaml \
  "${DEST_DIR}"/roles/defaults/main.yml \
  "${DEST_DIR}"/roles/defaults/main.yaml
do
  scrub_passwords_only "${f}"
done
shopt -u nullglob
scrub_ansible_cfg

echo "Done. Review before commit:"
echo "  cd ${DEST_DIR} && git status && git diff -- vars/ ansible.cfg"
echo "Source lab files were not modified."
