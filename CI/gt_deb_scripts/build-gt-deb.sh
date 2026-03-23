#!/bin/bash -e

# Script that generates gt .deb package and source files using debhelper

PACKAGE=${1:-gt}         # Default to gt, or specify package name as first argument
VERSION=${2:-1.0.0}      # Default to version 1.0.0
ARCHITECTURE=${3:-any}   # Default to any (host architecture), or specify: amd64, arm64, armhf, i386

WORK_DIR="${PACKAGE}-${VERSION}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ ! -d "${WORK_DIR}" ]; then
    echo "Error: Source directory '${WORK_DIR}' not found."
    echo "Please ensure the gt source code is checked out to '${WORK_DIR}'."
    exit 1
fi

# Create the orig tarball with exclusions
echo "Creating source tarball with exclusions..."
tar czf ${PACKAGE}_${VERSION}.orig.tar.gz \
    --exclude='.git' \
    --exclude='debian' \
    ${WORK_DIR}


# Copy debian directory into the extracted source tree
cp -r ${SCRIPT_DIR}/debian ${WORK_DIR}/

# Substitute variables in templates
cd ${WORK_DIR}

# Export all variables for envsubst and debian/rules
export VERSION ARCHITECTURE PACKAGE
export DATE=$(date -R)

# Create changelog entry
CHANGELOG_ENTRY="Build from master branch "
export CHANGELOG_ENTRY

# Substitute templates
envsubst < debian/control.template > debian/control
envsubst < debian/changelog.template > debian/changelog

# Remove template files
rm debian/*.template

# Build package using debhelper (builds both binary and source packages)
echo "Building packages for architecture: ${ARCHITECTURE}..."
if [ "${ARCHITECTURE}" = "any" ]; then
    # Build for host architecture
    dpkg-buildpackage -us -uc
else
    # Build for specific architecture
    dpkg-buildpackage -us -uc -a ${ARCHITECTURE}
fi

cd ..

echo ""
echo "Build complete! Generated files:"
echo "  - ${PACKAGE}_${VERSION}.orig.tar.gz (upstream source)"
echo "  - ${PACKAGE}_${VERSION}-1.debian.tar.xz (debian files)"
echo "  - ${PACKAGE}_${VERSION}-1.dsc (source descriptor)"
echo "  - ${PACKAGE}_${VERSION}-1_${ARCHITECTURE}.deb (binary package)"
