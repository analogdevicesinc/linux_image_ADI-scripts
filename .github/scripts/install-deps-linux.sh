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
    docker exec debian-armhf /bin/bash -c "
        set -e
        apt-get update && apt-get install -y ${DEPS} sudo
    "
    echo "::endgroup::"
else
    [[ "$ARCHITECTURE" == "arm64" ]] && SUDO="" || SUDO="sudo"

    echo "::group::Installing dependencies"
    ${SUDO} apt-get update
    DEBIAN_FRONTEND=noninteractive ${SUDO} apt-get install -y ${DEPS} sudo
    echo "::endgroup::"
fi
