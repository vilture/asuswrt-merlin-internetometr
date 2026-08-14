#!/bin/sh
# Build release tarball for Asuswrt-Merlin Internet-o-metr addon
set -e

ROOT="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
DIST="${ROOT}/dist/internetometr"
OUT="${ROOT}/asuswrt-merlin-internetometr.tar.gz"
VERSION="$(grep '^ADDON_VERSION=' "${ROOT}/src/backend/_globals.sh" | head -1 | cut -d= -f2 | tr -d '"')"

rm -rf "${ROOT}/dist"
mkdir -p "$DIST"

cp "${ROOT}/src/internetometr" "$DIST/internetometr"
cp "${ROOT}/src/backend/_globals.sh" "$DIST/"
cp "${ROOT}/src/backend/mount.sh" "$DIST/"
cp "${ROOT}/src/backend/install.sh" "$DIST/"
cp "${ROOT}/src/backend/run_speedtest.sh" "$DIST/"
cp "${ROOT}/src/backend/run_iperf.sh" "$DIST/"
cp "${ROOT}/src/backend/iperf_servers.sh" "$DIST/"
cp "${ROOT}/src/backend/iperf_servers.list" "$DIST/"
cp "${ROOT}/src/www/index.asp" "$DIST/"
cp "${ROOT}/src/www/internetometr.js" "$DIST/"

chmod 0755 "$DIST/internetometr" "$DIST/run_speedtest.sh" "$DIST/run_iperf.sh"

sed -i "s/^ADDON_VERSION=.*/ADDON_VERSION=\"${VERSION}\"/" "$DIST/_globals.sh" 2>/dev/null || \
	sed -i '' "s/^ADDON_VERSION=.*/ADDON_VERSION=\"${VERSION}\"/" "$DIST/_globals.sh"

tar -czf "$OUT" -C "${ROOT}/dist" internetometr

echo "Built ${OUT}"
echo "Version ${VERSION}"
tar -tzf "$OUT"
