#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
mkdir -p build/dashboard-tests
swiftc -module-cache-path "${TMPDIR:-/tmp}/mitsu-public-swift-cache" app/Mitsu/Core/*.swift tools/ReadPolicy.swift app/Tests/CoreTests.swift -o build/dashboard-tests/core-tests
build/dashboard-tests/core-tests
