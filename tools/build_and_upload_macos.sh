#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if ! command -v R >/dev/null 2>&1; then
  echo "R is required but not found in PATH." >&2
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "gh is required but not found in PATH." >&2
  exit 1
fi

VERSION_OVERRIDE="${1:-}"

detect_version_from_description() {
  local description_file="$1"
  awk -F': *' '/^Version:/ { print $2; exit }' "${description_file}"
}

cd "${REPO_ROOT}"

if [[ -n "${VERSION_OVERRIDE}" ]]; then
  VERSION="${VERSION_OVERRIDE}"
else
  VERSION="$(detect_version_from_description "${REPO_ROOT}/DESCRIPTION")"
fi

if [[ -z "${VERSION}" ]]; then
  echo "Could not determine package version." >&2
  exit 1
fi

SOURCE_TARBALL="ksTFL_${VERSION}.tar.gz"
BINARY_TARBALL="ksTFL_${VERSION}.tgz"
RELEASE_TAG="v${VERSION}"

echo "Version: ${VERSION}"
echo "Building source tarball..."
R CMD build .

if [[ ! -f "${SOURCE_TARBALL}" ]]; then
  echo "Expected source tarball not found: ${SOURCE_TARBALL}" >&2
  exit 1
fi

echo "Building macOS binary tarball from source..."
R CMD INSTALL --build "${SOURCE_TARBALL}"

if [[ ! -f "${BINARY_TARBALL}" ]]; then
  echo "Expected binary tarball not found: ${BINARY_TARBALL}" >&2
  exit 1
fi

echo "Uploading ${BINARY_TARBALL} to release ${RELEASE_TAG}..."
gh release upload "${RELEASE_TAG}" "${BINARY_TARBALL}"

echo "Done."
