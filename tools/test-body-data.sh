#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p build/body-data-tests
swiftc -module-cache-path "${TMPDIR:-/tmp}/mitsu-public-swift-cache" app/Mitsu/Core/OBDCodec.swift app/Mitsu/Core/Telemetry.swift app/Mitsu/Core/BodyState.swift app/Mitsu/Core/VehicleIdentityProfile.swift app/Mitsu/Core/BodyIdentityProbe.swift app/Mitsu/Core/BodyDataProbe.swift tests/DiagnosticFixtures.swift tests/BodyDataProbeTests.swift -o build/body-data-tests/check
build/body-data-tests/check
