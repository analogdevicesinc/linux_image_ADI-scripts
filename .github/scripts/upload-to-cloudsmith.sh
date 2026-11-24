#!/bin/bash

set -eo pipefail

# Env: WORKSPACE, PACKAGE_NAME, CONTAINER, CLOUDSMITH_ORG, CLOUDSMITH_REPO, CLOUDSMITH_VERSION
cd "${WORKSPACE}/artifacts"

# Determine distro tag from container
if [[ "${CONTAINER}" == *"kuiper"* ]]; then
    DISTRO_TAG="-kuiper"
elif [[ "${CONTAINER}" == "debian:latest" || "${CONTAINER}" == "debian:forky" ]]; then
    DISTRO_TAG="-debian"
else
    DISTRO_TAG=""
fi

# Source package files go to the raw repository
for f in "${PACKAGE_NAME}"*.dsc "${PACKAGE_NAME}"*.orig.tar.gz "${PACKAGE_NAME}"*.debian.tar.xz; do
    [[ -f "$f" ]] || continue
    cloudsmith push raw -SW --republish --no-wait-for-sync \
        --name "${f}" --tags "${f%%_*}${DISTRO_TAG}" --version "${CLOUDSMITH_VERSION}" \
        "${CLOUDSMITH_ORG}/${CLOUDSMITH_REPO}" "$f"
done

# Binary packages go to the debian repository
for f in "${PACKAGE_NAME}"_*.deb; do
    [[ -f "$f" ]] || continue
    cloudsmith push deb -SW --republish --no-wait-for-sync \
        "${CLOUDSMITH_ORG}/${CLOUDSMITH_REPO}/debian/trixie" "$f"
done
