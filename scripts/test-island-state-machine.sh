#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/coucou-fsm.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
swiftc -swift-version 6 -module-cache-path "$TEST_DIR/module-cache" \
    NotchBuddy/Sources/App/IslandStateMachine.swift \
    tests/IslandStateMachineTests.swift -o "$TEST_DIR/island-tests"
"$TEST_DIR/island-tests"
