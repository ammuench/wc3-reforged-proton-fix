#!/bin/bash
# Creates a copy of an installed GE-Proton (default: GE-Proton11-6-x86_64) named <name>-wc3fix
# with the patched crypt32.dll files from this repo. Restart Steam afterwards.
set -e
SRC_NAME="${1:-GE-Proton11-6-x86_64}"
TOOLS="${STEAM_COMPAT_TOOLS:-$HOME/.steam/root/compatibilitytools.d}"
SRC="$TOOLS/$SRC_NAME"
DST="$TOOLS/${SRC_NAME%-x86_64}-wc3fix"
HERE="$(cd "$(dirname "$0")" && pwd)"
[ -d "$SRC" ] || { echo "Source tool not found: $SRC"; exit 1; }
[ -e "$DST" ] && { echo "Already exists: $DST"; exit 1; }
echo "Copying $SRC -> $DST (takes a moment)"
cp -a "$SRC" "$DST"
NEW="$(basename "$DST")"
sed -i "s/\"$SRC_NAME\"/\"$NEW\"/g" "$DST/compatibilitytool.vdf"
for a in x86_64-windows i386-windows; do
  chmod u+w "$DST/files/lib/wine/$a/crypt32.dll"
  cp "$HERE/dlls/$a/crypt32.dll" "$DST/files/lib/wine/$a/crypt32.dll"
done
echo "$NEW" >> "$DST/version"
echo "Done. Restart Steam and select '$NEW' for Battle.net in Properties > Compatibility."
