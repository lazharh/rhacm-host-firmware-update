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

rsync -a --delete \
  --exclude '.git/' \
  --exclude '.gitignore' \
  --exclude '__pycache__/' \
  --exclude '*.pyc' \
  --exclude '.vault_pass' \
  --exclude '*.retry' \
  "${SRC_DIR}/" "${DEST_DIR}/"

# Scrub cleartext password values in destination YAML only.
# Leaves Jinja references like password: "{{ hub_password }}" untouched.
scrub_file() {
  local f="$1"
  [[ -f "${f}" ]] || return 0
  # Portable in-place edit
  local tmp
  tmp="$(mktemp)"
  # Clear hub/spoke/password scalars; skip Jinja "{{ ... }}" references.
  sed -E \
    -e 's/^([[:space:]]*hub_password:[[:space:]]*).+$/\1""/' \
    -e 's/^([[:space:]]*spoke_password:[[:space:]]*).+$/\1""/' \
    -e 's/^([[:space:]]*password:[[:space:]]*)"[^{"]*"/\1""/' \
    -e "s/^([[:space:]]*password:[[:space:]]*)'[^{']*'/\1''/" \
    "${f}" > "${tmp}"
  mv "${tmp}" "${f}"
  echo "  scrubbed: ${f#${DEST_DIR}/}"
}

echo "Scrubbing cleartext passwords in destination..."
shopt -s nullglob
for f in "${DEST_DIR}"/vars/*.yml "${DEST_DIR}"/vars/*.yaml; do
  scrub_file "${f}"
done
for f in \
  "${DEST_DIR}"/roles/*/defaults/main.yml \
  "${DEST_DIR}"/roles/*/defaults/main.yaml \
  "${DEST_DIR}"/roles/defaults/main.yml \
  "${DEST_DIR}"/roles/defaults/main.yaml
do
  scrub_file "${f}"
done
shopt -u nullglob

echo "Done. Review before commit:"
echo "  cd ${DEST_DIR} && git status && git diff -- vars/"
echo "Source lab passwords were not modified."
