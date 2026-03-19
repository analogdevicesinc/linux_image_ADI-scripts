#!/bin/bash -e

# Script that generates ADI scripts .deb package and source files using debhelper
# As a prerequire, the repository should be checked out before running this script


RELEASE=${1:-kuiper2.0}  	                    # Default to kuiper2.0 branch
VERSION=${2:-1.0.0}                             # Default to version 1.0.0
UPSTREAM_DIR=${3:-linux_image_ADI-scripts}      # Default to linux_image_ADI-scripts

# Package metadata
PACKAGE="adi-scripts"

# Set variable for github workflows
[ -n "$GITHUB_ENV" ] && echo "PACKAGE_NAME=$PACKAGE" >> $GITHUB_ENV

WORK_DIR="${PACKAGE}-${VERSION}"

# Rename extracted directory to match Debian conventions
cp -a ${UPSTREAM_DIR} ${WORK_DIR}

# Create the orig tarball with exclusions
echo "Creating source tarball with exclusions..."
tar czf ${PACKAGE}_${VERSION}.orig.tar.gz \
    --exclude='.git' \
    ${WORK_DIR}

# Substitute variables in templates
cd ${WORK_DIR}

# Copy debian directory into the extracted source tree
cp -r packaging/debian .

# Export all variables for envsubst and debian/rules
export VERSION PACKAGE RELEASE
export DATE=$(date -R)

# Create changelog entry
CHANGELOG_ENTRY="Build from ${RELEASE} branch"
export CHANGELOG_ENTRY

# Substitute templates
envsubst < debian/control.template > debian/control
envsubst < debian/changelog.template > debian/changelog

# Remove template files
rm debian/*.template

# Build package using debhelper (builds both binary and source packages)
echo "Building packages..."
dpkg-buildpackage -us -uc

cd ..

echo ""
echo "Build complete! Generated files:"
echo "  - ${PACKAGE}_${VERSION}.orig.tar.gz (upstream source)"
echo "  - ${PACKAGE}_${VERSION}-1.debian.tar.xz (debian files)"
echo "  - ${PACKAGE}_${VERSION}-1.dsc (source descriptor)"
echo "  - ${PACKAGE}_${VERSION}-1_all.deb (binary package)"
