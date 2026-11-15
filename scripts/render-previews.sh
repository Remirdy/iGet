#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
sources=()
while IFS= read -r -d '' source; do
    if [[ "$source" != 'iGet/iGetApp.swift' ]]; then sources+=("$source"); fi
done < <(find iGet App Packages OverlayEngine -name '*.swift' -print0)
swiftc -swift-version 5 "${sources[@]}" Tests/UI/RenderSmoke.swift -lsqlite3 -framework IOKit -o build/render-previews
IGET_RESOURCE_ROOT="$PWD" build/render-previews "$PWD/build/previews"
