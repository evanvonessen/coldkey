#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
# Explicit integration check: changes the live mode twice, restoring both snapshots on exit.
STAGING=$(mktemp -d "${TMPDIR:-/tmp}/coldkey-function-row.XXXXXX")
trap 'rm -rf "$STAGING"' EXIT
swiftc Sources/Coldkey/FunctionRowController.swift Tests/FunctionRow/main.swift -o "$STAGING/validate"
"$STAGING/validate"
