#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d /tmp/ipv64-core-tests.XXXXXX)"
trap 'rm -rf "$TEST_DIR"' EXIT

xcrun swiftc -parse-as-library -swift-version 5 \
  -module-cache-path "$TEST_DIR/module-cache" \
  "$PROJECT_DIR/IPv64/Helpers/APITransport.swift" \
  "$PROJECT_DIR/IPv64/Models/HealthCheck.swift" \
  "$PROJECT_DIR/IPv64/Models/HealthEvents.swift" \
  "$PROJECT_DIR/IPv64/Models/HealthCheckResult.swift" \
  "$PROJECT_DIR/IPv64/Models/Enum.swift" \
  "$PROJECT_DIR/IPv64/Helpers/SharedExtensions.swift" \
  "$PROJECT_DIR/Tests/CoreRegressionTests.swift" \
  -o "$TEST_DIR/core-regressions"
"$TEST_DIR/core-regressions"
