#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"
INSTANCE_ID="${APP_INSTANCE:-default}"
if [[ $# -gt 0 && "$1" != --* ]]; then
  INSTANCE_ID="$1"
  shift
fi

usage() {
  cat <<'EOF'
Usage:
  ./scripts/run_macos.sh [INSTANCE] [--host ORIGIN] [--realm REALM]

Examples:
  ./scripts/run_macos.sh
  ./scripts/run_macos.sh default --host http://localhost:7100
  ./scripts/run_macos.sh default --host https://api.alhambra.id --realm alhambra
EOF
}

HOST_ORIGIN=""
REALM="${TENANT_REALM:-alhambra}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)
      HOST_ORIGIN="$2"
      shift 2
      ;;
    --realm)
      REALM="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "[ERROR] Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

DB_PATH="build/macos/Build/Intermediates.noindex/XCBuildData/build.db"
DB_DIR="$(dirname "$DB_PATH")"

# If a stale XCBuild DB lock exists, clear it before running.
if [[ -f "$DB_PATH" ]]; then
  if command -v lsof >/dev/null 2>&1 && lsof "$DB_PATH" >/dev/null 2>&1; then
    echo "build.db is currently in use by another build process."
    echo "Stop the other Flutter/Xcode build, then rerun this script."
    exit 1
  fi

  echo "Removing stale XCBuildData lock files..."
  rm -rf "$DB_DIR"
fi

# IMPORTANT:
# Use "auto" by default so the app aligns with backend canonical user IDs.
# "username" can create legacy/duplicate DM rooms (uuid vs username) and can
# block strict E2EE sending when peer keys are published under UUID.
CHAT_USER_ID_SOURCE="${CHAT_USER_ID_SOURCE:-auto}"
MINA_PASSIVE_ROOMS="${MINA_PASSIVE_ROOMS:-3}"
ENABLE_FCM_PUSH="${ENABLE_FCM_PUSH:-false}"
echo "Running macOS app with APP_INSTANCE=$INSTANCE_ID CHAT_USER_ID_SOURCE=$CHAT_USER_ID_SOURCE MINA_PASSIVE_ROOMS=$MINA_PASSIVE_ROOMS ENABLE_FCM_PUSH=$ENABLE_FCM_PUSH"
EXTRA_DEFINES=()
if [[ -n "$HOST_ORIGIN" ]]; then
  BUILD_SHA="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
  BUILD_TIME="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  HOST_RAW="${HOST_ORIGIN%/}"
  SCHEME=""
  HOSTPORT=""
  if [[ "$HOST_RAW" == *"://"* ]]; then
    SCHEME="${HOST_RAW%%://*}"
    HOSTPORT="${HOST_RAW#*://}"
  else
    SCHEME="http"
    HOSTPORT="$HOST_RAW"
  fi
  HOSTPORT="${HOSTPORT%%/*}"
  ORIGIN="${SCHEME}://${HOSTPORT}"
  WS_SCHEME="ws"
  if [[ "$SCHEME" == "https" ]]; then
    WS_SCHEME="wss"
  fi
  EXTRA_DEFINES+=(
    --dart-define=AUTO_DETECT_HOST=false
    --dart-define=BACKEND_HOST="$HOSTPORT"
    --dart-define=TENANT_REALM="$REALM"
    --dart-define=AUTH_BASE_URL="${ORIGIN}/${REALM}/auth"
    --dart-define=CHAT_BASE_URL="${ORIGIN}/${REALM}/chat"
    --dart-define=CHAT_WS_BASE_URL="${WS_SCHEME}://${HOSTPORT}/${REALM}/chat"
    --dart-define=MINA_SIGNALING_WS_URL="${WS_SCHEME}://${HOSTPORT}/${REALM}/ws"
    --dart-define=MINA_NOTIFICATION_WS_URL="${WS_SCHEME}://${HOSTPORT}/${REALM}/notifications/ws"
    --dart-define=NOTIFICATION_API_BASE_URL="${ORIGIN}/${REALM}/notifications"
    --dart-define=ADMIN_BASE_URL="${ORIGIN}/${REALM}/admin"
    --dart-define=BUILD_SHA="$BUILD_SHA"
    --dart-define=BUILD_TIME="$BUILD_TIME"
  )
fi

flutter run -d macos \
  --dart-define=APP_INSTANCE="$INSTANCE_ID" \
  "${EXTRA_DEFINES[@]}" \
  --dart-define=ENABLE_FCM_PUSH="$ENABLE_FCM_PUSH" \
  --dart-define=CHAT_USER_ID_SOURCE="$CHAT_USER_ID_SOURCE" \
  --dart-define=MINA_PASSIVE_ROOMS="$MINA_PASSIVE_ROOMS"
