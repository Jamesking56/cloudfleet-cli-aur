#!/usr/bin/env bash
set -euo pipefail

PKGBUILD_FILE="PKGBUILD"
DOCS_URL="https://cloudfleet.ai/docs/introduction/install-cloudfleet-cli/"

echo "Fetching current pkgver..."
CUR_VER=$(grep -oP '^pkgver\s*=\s*\K[0-9]+\.[0-9]+\.[0-9]+' "$PKGBUILD_FILE") || {
  echo "ERROR: Could not parse current pkgver in PKGBUILD"
  exit 1
}
echo "Current pkgver: $CUR_VER"

echo "Fetching docs page..."
HTML=$(curl -fsSL -A "Mozilla/5.0 (compatible; CloudfleetUpdater/1.0)" "$DOCS_URL") || {
  echo "ERROR: curl failed to fetch $DOCS_URL"
  exit 1
}
echo "Downloaded docs page"

echo "Extracting version numbers from download links..."
VERSIONS=$(echo "$HTML" \
  | grep -oP 'https://downloads\.cloudfleet\.ai/cli/\K[0-9]+\.[0-9]+\.[0-9]+(?=/cloudfleet_linux_(amd64|arm64)\.zip)' \
  | sort -V \
  | uniq)

if [[ -z "$VERSIONS" ]]; then
  echo "ERROR: No version numbers found in docs page!"
  exit 1
fi

LATEST=$(echo "$VERSIONS" | tail -n1)
echo "Detected latest version: $LATEST"

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
