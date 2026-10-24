#!/bin/zsh
set -eu
cd "${0:A:h}/.."
mkdir -p build/policy-test
cat tools/ReadPolicy.swift tests/ReadPolicyTests.swift > build/policy-test/main.swift
swiftc -module-cache-path "${TMPDIR:-/tmp}/mitsu-public-policy-cache" build/policy-test/main.swift -o build/policy-test/check
build/policy-test/check
