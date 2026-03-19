#!/bin/bash -e

# Script that generates ADI scripts .deb package and source files using debhelper
# Usage: build-adi-scripts-deb.sh <source-dir> [release] [version]

SOURCE_DIR="$(cd "$1" && pwd)"
RELEASE=${2:-kuiper2.0}
VERSION=${3:-1.0.0}
PACKAGE="adi-scripts"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$(dirname "${SOURCE_DIR}")"
OUTPUT_DIR="${WORKSPACE}/output"

mkdir -p "${OUTPUT_DIR}"

# Create the orig tarball (dpkg-buildpackage expects it in the parent of the source dir)
echo "Creating source tarball..."
tar czf "${WORKSPACE}/${PACKAGE}_${VERSION}.orig.tar.gz" \
    -C "${WORKSPACE}" "$(basename "${SOURCE_DIR}")"

# Copy debian metadata into the source tree
cp -r "${SCRIPT_DIR}/debian" "${SOURCE_DIR}/debian"

# Export variables for envsubst
export PACKAGE VERSION RELEASE
export DATE=$(date -R)
export CHANGELOG_ENTRY="  * Build from ${RELEASE} branch"

# Substitute templates
cd "${SOURCE_DIR}"
envsubst < debian/control.template > debian/control
envsubst < debian/changelog.template > debian/changelog
rm debian/*.template

# Build package (artifacts are output to parent directory by dpkg-buildpackage)
echo "Building packages..."
dpkg-buildpackage -us -uc

# Move generated artifacts to output directory
cd "${WORKSPACE}"
HOST_ARCH=$(dpkg --print-architecture)
mv "${PACKAGE}_${VERSION}.orig.tar.gz" "${OUTPUT_DIR}/"
mv "${PACKAGE}_${VERSION}-1.dsc" "${OUTPUT_DIR}/"
mv "${PACKAGE}_${VERSION}-1.debian.tar.xz" "${OUTPUT_DIR}/"
mv "${PACKAGE}_${VERSION}-1_all.deb" "${OUTPUT_DIR}/"
mv "${PACKAGE}_${VERSION}-1_${HOST_ARCH}.buildinfo" "${OUTPUT_DIR}/"
mv "${PACKAGE}_${VERSION}-1_${HOST_ARCH}.changes" "${OUTPUT_DIR}/"

echo ""
echo "Build complete! Artifacts in ${OUTPUT_DIR}:"
ls -1 "${OUTPUT_DIR}/"
