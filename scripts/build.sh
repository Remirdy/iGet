#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
configuration=Debug
run_tests=false
for argument in "$@"; do
    case "$argument" in
        --release) configuration=Release ;;
        --test) run_tests=true ;;
        *) printf 'Usage: %s [--release] [--test]\n' "$0"; exit 1 ;;
    esac
done
if ! xcodebuild -version >/dev/null 2>&1; then
    printf 'Full Xcode is required for the app and WidgetKit extension. Use scripts/build-local.sh for the standalone desktop app.\n' >&2
    exit 1
fi
xcodebuild -project iGet.xcodeproj -scheme iGet -configuration "$configuration" -destination 'platform=macOS' -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build
if [[ "$run_tests" == true ]]; then
    ./scripts/test.sh
    ./scripts/test-integration.sh
    ./scripts/test-services.sh
fi
