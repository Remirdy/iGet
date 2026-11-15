#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
swiftc -swift-version 5 Packages/iGetCore/Sources/iGetCore/*.swift App/Integration/Services/ConnectedServices.swift Tests/Integration/ConnectedServicesTests.swift -o build/service-tests
build/service-tests
