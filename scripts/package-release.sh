#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

version="0.3.0"
project_root="$PWD"
release_dir="$project_root/build/releases"
host_arch="$(uname -m)"
tmp_dirs=()

cleanup() {
    for dir in "${tmp_dirs[@]:-}"; do
        if [[ -n "$dir" && -d "$dir" ]]; then
            rm -rf "$dir"
        fi
    done
}
trap cleanup EXIT

rm -rf "$release_dir"
mkdir -p "$release_dir" "$project_root/build"

arm_zip="$release_dir/iGet-${version}-apple-silicon.zip"
intel_zip="$release_dir/iGet-${version}-intel.zip"

IGET_ARCH=arm64 IGET_PACKAGE_PATH="$arm_zip" ./scripts/build-local.sh --release
IGET_ARCH=x86_64 IGET_PACKAGE_PATH="$intel_zip" ./scripts/build-local.sh --release

cp "$arm_zip" "$project_root/build/iGet-apple-silicon.zip"
cp "$intel_zip" "$project_root/build/iGet-intel.zip"
if [[ "$host_arch" == "x86_64" ]]; then
    cp "$intel_zip" "$project_root/build/iGet.zip"
else
    cp "$arm_zip" "$project_root/build/iGet.zip"
fi

verify_archive() {
    local zip_path="$1"
    local expected_arch="$2"
    local tmp_dir
    tmp_dir="$(mktemp -d)"
    tmp_dirs+=("$tmp_dir")

    unzip -t "$zip_path" >/dev/null
    if unzip -l "$zip_path" | grep '\.DS_Store' >/dev/null; then
        printf 'Unexpected .DS_Store inside %s\n' "$zip_path" >&2
        exit 1
    fi

    ditto -x -k "$zip_path" "$tmp_dir"
    local app_bundle="$tmp_dir/iGet.app"
    local actual_arch
    actual_arch="$(lipo -archs "$app_bundle/Contents/MacOS/iGet")"
    if [[ "$actual_arch" != "$expected_arch" ]]; then
        printf 'Expected arch %s in %s, got %s\n' "$expected_arch" "$zip_path" "$actual_arch" >&2
        exit 1
    fi

    local actual_version
    actual_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app_bundle/Contents/Info.plist")"
    if [[ "$actual_version" != "$version" ]]; then
        printf 'Expected version %s in %s, got %s\n' "$version" "$zip_path" "$actual_version" >&2
        exit 1
    fi

    local required_files=(
        "Contents/Resources/AppIcon.icns"
        "Contents/Resources/BrandLogo.png"
        "Contents/Resources/en.lproj/Localizable.strings"
        "Contents/Resources/en.lproj/InfoPlist.strings"
        "Contents/Resources/tr.lproj/Localizable.strings"
        "Contents/Resources/tr.lproj/InfoPlist.strings"
        "Contents/Resources/de.lproj/Localizable.strings"
        "Contents/Resources/de.lproj/InfoPlist.strings"
    )
    for rel_path in "${required_files[@]}"; do
        if [[ ! -f "$app_bundle/$rel_path" ]]; then
            printf 'Missing %s inside %s\n' "$rel_path" "$zip_path" >&2
            exit 1
        fi
    done

    codesign --verify --deep --strict "$app_bundle"
    printf 'Verified (%s) %s\n' "$expected_arch" "$zip_path"
}

verify_archive "$arm_zip" "arm64"
verify_archive "$intel_zip" "x86_64"

(
    cd "$release_dir"
    shasum -a 256 "iGet-${version}-apple-silicon.zip" "iGet-${version}-intel.zip" > SHA256SUMS.txt
    shasum -a 256 -c SHA256SUMS.txt
)

(
    cd "$project_root/build"
    shasum -a 256 iGet-apple-silicon.zip iGet-intel.zip > SHA256SUMS.txt
    shasum -a 256 -c SHA256SUMS.txt
)

printf '\nRelease packages ready in %s:\n' "$release_dir"
ls -lh "$release_dir"
printf '\nSHA-256 checksums:\n'
cat "$release_dir/SHA256SUMS.txt"
