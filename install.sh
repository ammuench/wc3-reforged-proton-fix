#!/bin/bash
set -e

# If flag is passed, target proton-plus default directory for use outside of steam (lutris, etc)
PROTON_PLUS=0
if [ "$1" = "--proton-plus" ]; then
  PROTON_PLUS=1
  shift
fi

if [ "$PROTON_PLUS" -eq 1 ]; then
  SRC_NAME="${1:-GE-Proton11-6}"
  DEFAULT_TOOLS="$HOME/.local/share/Steam/compatibilitytools.d"
else
  SRC_NAME="${1:-GE-Proton11-6-x86_64}"
  DEFAULT_TOOLS="$HOME/.steam/root/compatibilitytools.d"
fi

TOOLS="${STEAM_COMPAT_TOOLS:-$DEFAULT_TOOLS}"
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
