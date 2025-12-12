#!/usr/bin/env bash
set -euo pipefail

PKGBUILD_FILE="PKGBUILD"

# VERSION should be set by the GitHub Action from `cloudfleet --version`
if [[ -z "${VERSION:-}" ]]; then
  echo "ERROR: VERSION environment variable is not set"
  exit 1
fi

LATEST="$VERSION"
echo "Target version: $LATEST"

echo "Fetching current pkgver..."
CUR_VER=$(grep -oE '^pkgver\s*=\s*[0-9]+\.[0-9]+\.[0-9]+' "$PKGBUILD_FILE" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+') || {
  echo "ERROR: Could not parse current pkgver in PKGBUILD"
  exit 1
}
echo "Current pkgver: $CUR_VER"

# Early exit if already up-to-date
if [[ "$LATEST" == "$CUR_VER" ]]; then
  echo "Already up-to-date ($CUR_VER). Nothing to do."
  exit 0
fi

echo "Updating from $CUR_VER → $LATEST"

ARCHES=("amd64" "arm64")
declare -A CHECKSUMS

# Download and compute checksum for both architectures
for a in "${ARCHES[@]}"; do
    URL="https://downloads.cloudfleet.ai/cli/${LATEST}/cloudfleet_linux_${a}.zip"
    FILENAME="cloudfleet_linux-${a}-${LATEST}.zip"

    echo "Downloading $URL..."
    curl -fsSL "$URL" -o "$FILENAME"

    CHECKSUMS[$a]=$(sha256sum "$FILENAME" | cut -d ' ' -f1)
    echo "$a checksum: ${CHECKSUMS[$a]}"

    # Remove temporary archive
    rm -f "$FILENAME"
done

echo "Updating PKGBUILD..."
sed -i "s/^pkgver\s*=.*/pkgver=${LATEST}/" "$PKGBUILD_FILE"
sed -i "/^sha256sums=/c\sha256sums=('${CHECKSUMS[amd64]}' '${CHECKSUMS[arm64]}')" "$PKGBUILD_FILE"

echo "Regenerating .SRCINFO..."
makepkg --printsrcinfo > .SRCINFO

echo "Update complete!"
