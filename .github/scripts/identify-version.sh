#!/bin/bash

set -eo pipefail

# Env (all optional):
#   VERSION_FILE      file holding the package version (default: packaging/VERSION)
#   CLOUDSMITH_PREFIX prefix of the cloudsmith version label (default: adi-scripts)
VERSION_FILE="${VERSION_FILE:-packaging/VERSION}"
CLOUDSMITH_PREFIX="${CLOUDSMITH_PREFIX:-adi-scripts}"

ci_version=""
[[ -f "$VERSION_FILE" ]] && ci_version=$(tr -d '[:space:]' < "$VERSION_FILE")

if [[ -z "$ci_version" ]]; then
	echo "Failed to read version from ${VERSION_FILE}, using default"
	ci_version="0.0.1+${GITHUB_SHA}"
fi

echo "CI Version to use: $ci_version"
echo "ci-version=$ci_version" >> "$GITHUB_OUTPUT"

# Extract version from ref for the CLOUDSMITH_VERSION
cloudsmith_version=""
if [[ "${GITHUB_REF}" == *"refs/tags/v"* ]]; then
	cloudsmith_version="${CLOUDSMITH_PREFIX}-${GITHUB_REF#refs/tags/}"
elif [[ "${GITHUB_REF}" == "refs/heads/main" ]]; then
	cloudsmith_version="${CLOUDSMITH_PREFIX}-main~latest"
elif [[ "${GITHUB_REF}" == *"refs/pull/"* ]]; then
	pr_number=$(echo "$GITHUB_REF" | sed -e "s#refs/##g" -e "s#/merge##g" -e "s#/#-#g")
	cloudsmith_version="${CLOUDSMITH_PREFIX}-${pr_number}"
fi

echo "Cloudsmith version to use: $cloudsmith_version"
echo "cloudsmith-version=$cloudsmith_version" >> "${GITHUB_OUTPUT}"
