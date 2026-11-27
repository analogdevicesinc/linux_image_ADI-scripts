#!/bin/bash

set -eo pipefail

# Configure the private Cloudsmith apt repository manually (must run as root).
# The generated setup.deb.sh does not forward basic-auth credentials to its own
# requests (GPG key / config), so it fails on private repos - do it by hand.
# Env: CLOUDSMITH_ORG, CLOUDSMITH_REPO, CLOUDSMITH_USERNAME, CLOUDSMITH_API_KEY
# Optional: CLOUDSMITH_GPG_KEY_ID (repo signing key id), CLOUDSMITH_DISTRO, CLOUDSMITH_CODENAME
# The repo is flat, so a supported distro is forced - Ubuntu 24.04/26.04 and Debian
# testing (forky) are not reliably auto-detected.

: "${CLOUDSMITH_ORG:?}" "${CLOUDSMITH_REPO:?}" "${CLOUDSMITH_USERNAME:?}" "${CLOUDSMITH_API_KEY:?}"
KEY_ID="${CLOUDSMITH_GPG_KEY_ID:-85421AD6CC87F02A}"
DISTRO="${CLOUDSMITH_DISTRO:-debian}"
CODENAME="${CLOUDSMITH_CODENAME:-trixie}"

BASE="https://dl.cloudsmith.io/basic/${CLOUDSMITH_ORG}/${CLOUDSMITH_REPO}"
NAME="${CLOUDSMITH_ORG}-${CLOUDSMITH_REPO}"
KEYRING="/usr/share/keyrings/${NAME}-archive-keyring.gpg"
LIST="/etc/apt/sources.list.d/${NAME}.list"
AUTH="/etc/apt/auth.conf.d/${NAME}.conf"

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y apt-transport-https ca-certificates curl gnupg

CURL=(curl -u "${CLOUDSMITH_USERNAME}:${CLOUDSMITH_API_KEY}" -1sSL --fail-with-body)

rm -f "${KEYRING}"
"${CURL[@]}" "${BASE}/gpg.${KEY_ID}.key" | gpg --dearmor > "${KEYRING}"
"${CURL[@]}" "${BASE}/config.deb.txt?distro=${DISTRO}&codename=${CODENAME}&component=main" > "${LIST}"

# apt authentication for the private repo
mkdir -p /etc/apt/auth.conf.d
printf 'machine dl.cloudsmith.io login %s password %s\n' "${CLOUDSMITH_USERNAME}" "${CLOUDSMITH_API_KEY}" > "${AUTH}"
chmod 600 "${AUTH}"
chmod 644 "${KEYRING}" "${LIST}"

# Make sure the key path used by the list matches the one we installed
grep -q "signed-by" "${LIST}" && sed -i "s#signed-by=[^] ]*#signed-by=${KEYRING}#" "${LIST}"

apt-get update
