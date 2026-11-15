#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
swiftc -swift-version 5 Packages/iGetCore/Sources/iGetCore/*.swift Packages/iGetData/Sources/iGetData/WorkspaceDatabase.swift Tests/Core/*.swift -lsqlite3 -o build/workspace-tests
build/workspace-tests
