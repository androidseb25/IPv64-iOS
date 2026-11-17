#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d /tmp/ipv64-node-sync-tests.XXXXXX)"
trap 'rm -rf "$TEST_DIR"' EXIT
xcrun swiftc -parse-as-library -swift-version 5 -module-cache-path "$TEST_DIR/module-cache" \
  "$PROJECT_DIR/IPv64/Helpers/Nodes/NodeSyncPlan.swift" "$PROJECT_DIR/Tests/NodeSyncPlanTests.swift" \
  -o "$TEST_DIR/node-sync-tests"
"$TEST_DIR/node-sync-tests"
