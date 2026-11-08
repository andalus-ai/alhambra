#!/bin/bash
set -euo pipefail

HOST="${ALHAMBRA_HOST:-https://api.alhambra.id}"
REALM="${TENANT_REALM:-alhambra}"

exec ./scripts/run_macos.sh default --host "$HOST" --realm "$REALM" "$@"
