#!/usr/bin/env bash
set -euo pipefail

app_dir="$(cd "$(dirname "$0")/.." && pwd)"
test_temp="$(mktemp -d "${TMPDIR:-/tmp}/ldc-tests.XXXXXX")"
trap 'rm -rf "$test_temp"' EXIT
compiler_args=(-swift-version 5 -warnings-as-errors)
if [[ "${1:-}" == "--sanitize-thread" ]]; then
  compiler_args+=(-sanitize=thread)
fi

xcrun swiftc "${compiler_args[@]}" \
  "$app_dir/Tests/LDCStatusCheckerTests.swift" \
  "$app_dir/Tests/Fixtures/LDCInMemoryDeviceStore.swift" \
  "$app_dir/ViewModels/LDCDeviceRepository.swift" \
  "$app_dir/Services/LDCSSHClient.swift" \
  "$app_dir/Services/LDCExpectSSHClient.swift" \
  "$app_dir/Services/LDCTerminalLauncher.swift" \
  "$app_dir/Models/LDCDevice.swift" \
  "$app_dir/Services/LDCStatusChecker.swift" \
  "$app_dir/Models/LDCDeviceStatus.swift" \
  -o "$test_temp/status-checker-tests"
"$test_temp/status-checker-tests"

xcrun swiftc "${compiler_args[@]}" -target "$(uname -m)-apple-macos14.0" \
  "$app_dir/Tests/LDCDiscoveryTests.swift" \
  "$app_dir/Services/LDCDiscoveryService.swift" \
  "$app_dir/Services/LDCReverseDNSResolver.swift" \
  "$app_dir/Services/LDCSubnetScanner.swift" \
  "$app_dir/Services/LDCStatusChecker.swift" \
  "$app_dir/Models/LDCDeviceStatus.swift" \
  -o "$test_temp/discovery-tests"
"$test_temp/discovery-tests"
