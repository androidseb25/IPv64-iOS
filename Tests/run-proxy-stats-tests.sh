#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d /tmp/ipv64-proxy-stats-tests.XXXXXX)"
trap 'rm -rf "$TEST_DIR"' EXIT
xcrun swiftc -parse-as-library -swift-version 5 -module-cache-path "$TEST_DIR/module-cache" \
  "$PROJECT_DIR/IPv64/Helpers/Proxy/ProxyStats.swift" "$PROJECT_DIR/Tests/ProxyStatsTests.swift" \
  -o "$TEST_DIR/proxy-stats-tests"
"$TEST_DIR/proxy-stats-tests"
