#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
configuration="${1:---release}"
host_arch="$(uname -m)"
architecture="${IGET_ARCH:-$host_arch}"
project_root="$PWD"
if [[ -n "${IGET_BUILD_ROOT:-}" ]]; then
    build_root="$IGET_BUILD_ROOT"
elif [[ "$architecture" == "$host_arch" ]]; then
    build_root="$HOME/Library/Caches/iGet/Build"
else
    build_root="$HOME/Library/Caches/iGet/Build-$architecture"
fi
package_path="${IGET_PACKAGE_PATH:-$project_root/build/iGet.zip}"
link_app="${IGET_LINK_APP:-auto}"
app_path="$build_root/iGet.app"
rm -rf "$app_path"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"
cp Config/AppIcon.icns "$app_path/Contents/Resources/AppIcon.icns"
cp Config/BrandLogo.png "$app_path/Contents/Resources/BrandLogo.png"
cp -R Config/Localization/*.lproj "$app_path/Contents/Resources/"
find "$app_path" -name '.DS_Store' -delete
flags=(-Osize -whole-module-optimization)
if [[ "$configuration" == '--debug' ]]; then flags=(-Onone -g); fi
sources=()
while IFS= read -r -d '' source; do sources+=("$source"); done < <(find iGet App Packages OverlayEngine -name '*.swift' -print0 | sort -z)
swiftc -swift-version 5 -target "$architecture-apple-macosx14.0" "${flags[@]}" "${sources[@]}" -lsqlite3 -framework IOKit -o "$app_path/Contents/MacOS/iGet"
/usr/libexec/PlistBuddy -c 'Print' iGet/Info.plist > /dev/null
python3 - "$app_path" <<'PY'
import plistlib
import sys
from pathlib import Path
app = Path(sys.argv[1])
with open('iGet/Info.plist', 'rb') as file:
    info = plistlib.load(file)
info.update(CFBundleExecutable='iGet', CFBundleIdentifier='com.twobitdev.iGet.local', CFBundleShortVersionString='0.3.0', CFBundleVersion='3')
with open(app / 'Contents/Info.plist', 'wb') as file:
    plistlib.dump(info, file)
PY
xattr -cr "$app_path"
codesign --force --sign - --entitlements Config/Local.entitlements "$app_path"
codesign --verify --deep --strict "$app_path"
mkdir -p "$project_root/build" "$(dirname "$package_path")"
if [[ "$link_app" == '1' || ( "$link_app" == 'auto' && "$architecture" == "$host_arch" ) ]]; then
    if [[ -L "$project_root/build/iGet.app" ]]; then
        rm "$project_root/build/iGet.app"
    elif [[ -d "$project_root/build/iGet.app" ]]; then
        rm -rf "$project_root/build/iGet.app"
    fi
    ln -s "$app_path" "$project_root/build/iGet.app"
fi
rm -f "$package_path"
ditto -c -k --keepParent --norsrc --noextattr "$app_path" "$package_path"
printf 'Built (%s) %s -> %s\n' "$architecture" "$app_path" "$package_path"
du -sh "$app_path" "$package_path"
