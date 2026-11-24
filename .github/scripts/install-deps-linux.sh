#!/bin/bash

set -eo pipefail

# Env: ARCHITECTURE, CONTAINER, PLATFORM (armhf only)
# The armhf build runs in a persistent emulated container (debian-armhf) with
# the workspace mounted at /workspace. amd64/arm64 build directly on the runner
# (arm64 inside the job container).

DEPS="build-essential devscripts debhelper gettext git curl ca-certificates rsync"

if [[ "$ARCHITECTURE" == "armhf" ]]; then
    docker run --platform "${PLATFORM}" \
        --name debian-armhf \
        -v "${GITHUB_WORKSPACE}:/workspace" \
        -dit "${CONTAINER}"

    echo "::group::Installing dependencies"
    docker exec \
        -e PACKAGE_NAME=${PACKAGE_NAME} \
        -e CLOUDSMITH_ORG=${CLOUDSMITH_ORG} \
        -e CLOUDSMITH_USERNAME=${CLOUDSMITH_USERNAME} \
        -e CLOUDSMITH_REPO=${CLOUDSMITH_REPO} \
        -e CLOUDSMITH_API_KEY=${CLOUDSMITH_API_KEY} \
        -e GT_DEBIAN_VERSION=${GT_DEBIAN_VERSION} \
        -w /workspace \
        debian-armhf \
        /bin/bash -c "
        set -eo pipefail
        apt-get update && apt-get install -y ${DEPS} sudo
        
        # Install downloaded gt artifact
        if [[ \"\$PACKAGE_NAME\" == \"adi-scripts\" ]]; then
            /workspace/.github/scripts/setup-cloudsmith-apt.sh
            apt-cache policy gt || true
            apt-get install -y gt=\${GT_DEBIAN_VERSION}
        fi
    "
    echo "::endgroup::"
else
    [[ "$ARCHITECTURE" == "arm64" ]] && SUDO="" || SUDO="sudo"

    echo "::group::Installing dependencies"
    ${SUDO} apt-get update
    DEBIAN_FRONTEND=noninteractive ${SUDO} apt-get install -y ${DEPS} sudo
    
    # Install downloaded gt artifact
    if [[ "$PACKAGE_NAME" == "adi-scripts" ]]; then
        [[ -n "${CLOUDSMITH_API_KEY}" ]] || { echo "::error::CLOUDSMITH_API_KEY is empty (Setup cloudsmith step did not export it)"; exit 1; }
        [[ -n "${CLOUDSMITH_USERNAME}" && -n "${CLOUDSMITH_ORG}" && -n "${CLOUDSMITH_REPO}" ]] || { echo "::error::CLOUDSMITH_USERNAME/ORG/REPO is empty"; exit 1; }
        # sudo-rs (Ubuntu 26.04) ignores -E, so pass the variables explicitly
        ${SUDO} env CLOUDSMITH_ORG="${CLOUDSMITH_ORG}" CLOUDSMITH_REPO="${CLOUDSMITH_REPO}" \
            CLOUDSMITH_USERNAME="${CLOUDSMITH_USERNAME}" CLOUDSMITH_API_KEY="${CLOUDSMITH_API_KEY}" \
            bash .github/scripts/setup-cloudsmith-apt.sh
        apt-cache policy gt || true
        ${SUDO} apt-get install -y "gt=${GT_DEBIAN_VERSION}"
    fi
    
    echo "::endgroup::"
fi
