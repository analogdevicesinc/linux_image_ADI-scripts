#!/bin/bash

set -eo pipefail

# Env: ARCHITECTURE, CONTAINER, CI_VERSION, VERSION_SUFFIX, PACKAGE_NAME,
#      CONTROL_PATH (default packaging/debian), ARTIFACTS_DIR (amd64/arm64:
#      output of the deb action),
#      GITHUB_ENV
CONTROL_PATH="${CONTROL_PATH:-packaging/debian}"
# Packages may be Architecture: all, so match any architecture in the filename
DEB_GLOB="${PACKAGE_NAME}_${CI_VERSION}-1${VERSION_SUFFIX}_*.deb"

if [[ "$ARCHITECTURE" == 'armhf' ]]; then
    echo "Building debian package for armhf ..."
    docker exec \
        -e VERSION="$CI_VERSION" \
        -e WORKING_DIRECTORY="/workspace" \
        -e GITHUB_WORKSPACE="/workspace" \
        -e IGNORE_PATH="packaging" \
        -e CONTROL_PATH="$CONTROL_PATH" \
        -e VERSION_SUFFIX="$VERSION_SUFFIX" \
        -w /workspace \
        debian-armhf \
        /bin/bash -c "
            set -e
            git clone https://github.com/analogdevicesinc/shared-actions /tmp/shared-actions
            /tmp/shared-actions/deb-generator-action/build-deb.sh
        "

    # Installation and verification of package
    docker exec -w /workspace/artifacts debian-armhf \
        /bin/bash -c "set -e; apt-get install -y ./${DEB_GLOB}"

    # Artifacts are already on the host through the workspace mount
    ARTIFACTS_DIR="${GITHUB_WORKSPACE}/artifacts"
else
    [[ "$ARCHITECTURE" == "arm64" ]] && SUDO="" || SUDO="sudo"
    ${SUDO} apt-get install -y ${ARTIFACTS_DIR}/${DEB_GLOB}
fi

# Orig tarball is only needed for the source package
rm -rf "${ARTIFACTS_DIR}/${PACKAGE_NAME}_${CI_VERSION}.orig.tar" 2>/dev/null || true

# Create debian output name - differentiate by distro
if [[ "${CONTAINER}" == *"kuiper"* ]]; then
    distro_tag="kuiper"
elif [[ "${CONTAINER}" == "debian:latest" || "${CONTAINER}" == "debian:forky" ]]; then
    distro_tag="debian"
else
    distro_tag="ubuntu"
fi

# On armhf the os-release has to be read from inside the container
if [[ "$ARCHITECTURE" == 'armhf' ]]; then
    os_release=$(docker exec debian-armhf cat /etc/os-release)
else
    os_release=$(cat /etc/os-release)
fi

version_id=$(echo "$os_release" | grep "^VERSION_ID" | cut -d "=" -f2 | tr -d '"' || true)

# Cloudsmith distribution (e.g. debian/trixie, ubuntu/noble) comes from the os-release of the build system
distribution_id=$(echo "$os_release" | grep "^ID=" | cut -d "=" -f2 | tr -d '"' || true)
distribution_codename=$(echo "$os_release" | grep "^VERSION_CODENAME" | cut -d "=" -f2 | tr -d '"' || true)
# Debian testing (forky) has no VERSION_ID - fall back to the codename
[[ -z "$version_id" ]] && version_id=$(echo "$os_release" | grep "^VERSION_CODENAME" | cut -d "=" -f2 | tr -d '"') || true

echo "DEBIAN_ARTIFACT=${PACKAGE_NAME}-deb-${ARCHITECTURE}-${distro_tag}-${version_id}" >> "$GITHUB_ENV"
echo "DISTRIBUTION_NAME=${distribution_id}/${distribution_codename}" >> "$GITHUB_ENV"
