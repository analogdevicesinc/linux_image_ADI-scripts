#!/bin/bash

set -eo pipefail

# Env: WORKSPACE, PACKAGE_NAME, CONTAINER, CLOUDSMITH_ORG, CLOUDSMITH_REPO, CLOUDSMITH_VERSION
cd "${WORKSPACE}/artifacts"

# Binary packages go to the debian repository. Source package files (.dsc, .orig.tar.gz, .debian.tar.xz) are not uploaded
for f in "${PACKAGE_NAME}"_*.deb; do
    [[ -f "$f" ]] || continue
    cloudsmith push deb --republish --no-wait-for-sync \
        "${CLOUDSMITH_ORG}/${CLOUDSMITH_REPO}/${DISTRIBUTION_NAME}" "$f"
done
