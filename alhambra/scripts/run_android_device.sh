#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/run_android_device.sh [--host ORIGIN] [--realm REALM]

  ./scripts/run_android_device.sh --host https://api.alhambra.id --realm alhambra

Notes:
  - If --host is provided, the app will use gateway-style routes:
    ORIGIN/<realm>/auth, ORIGIN/<realm>/chat, ORIGIN/<realm>/ws, etc.
  - If --host is not provided, the script falls back to direct service ports
    on the detected LAN IP (identity 7101, chat 7109, mina signaling 2443).
EOF
}

HOST_ORIGIN=""
TENANT_REALM="${TENANT_REALM:-alhambra}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)
      HOST_ORIGIN="$2"
      shift 2
      ;;
    --realm)
      TENANT_REALM="$2"
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

if ! command -v adb >/dev/null 2>&1; then
  echo "[ERROR] adb not found. Please install Android platform tools."
  exit 1
fi

get_host_ip() {
  local ip=""
  if command -v ipconfig >/dev/null 2>&1; then
    ip="$(ipconfig getifaddr en0 2>/dev/null || true)"
    if [ -z "$ip" ]; then
      ip="$(ipconfig getifaddr en1 2>/dev/null || true)"
    fi
  fi
  if [ -z "$ip" ] && command -v ifconfig >/dev/null 2>&1; then
    ip="$(ifconfig | awk '/inet / && $2 != "127.0.0.1" {print $2; exit}')"
  fi
  echo "$ip"
}

can_reach_host() {
  local host="$1"
  local port="${2:-7101}"
  if [ -z "$host" ]; then
    return 1
  fi
  # Try TCP connect using bash built-in /dev/tcp (fast, no extra deps).
  timeout 1 bash -c "cat < /dev/null > /dev/tcp/${host}/${port}" >/dev/null 2>&1
}

select_device() {
  local devices=()
  while read -r line; do
    [ -z "$line" ] && continue
    devices+=("$line")
  done < <(adb devices -l | awk 'NR>1 && $2=="device" {print $1}')
  if [ ${#devices[@]} -eq 0 ]; then
    echo "[ERROR] No Android device detected. Connect a device or start an emulator."
    exit 1
  fi
  if [ ${#devices[@]} -eq 1 ]; then
    echo "${devices[0]}"
    return
  fi
  echo "[INFO] Multiple devices detected:"
  local idx=1
  for dev in "${devices[@]}"; do
    echo "  [$idx] $dev"
    idx=$((idx + 1))
  done
  local choice=""
  while true; do
    read -r -p "Select device (1-${#devices[@]}): " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#devices[@]}" ]; then
      echo "${devices[$((choice - 1))]}"
      return
    fi
    echo "Invalid selection."
  done
}

DEVICE_ID="${ANDROID_DEVICE_ID:-$(select_device)}"
AUTO_DETECTED_IP="$(get_host_ip)"
DEFAULT_BACKEND_HOST="${DEFAULT_BACKEND_HOST:-192.168.8.184}"

# IMPORTANT:
# Use "auto" by default so the app aligns with backend canonical user IDs.
# "username" can create legacy/duplicate DM rooms (uuid vs username) and can
# block strict E2EE sending when peer keys are published under UUID.
CHAT_USER_ID_SOURCE="${CHAT_USER_ID_SOURCE:-auto}"
ENABLE_FCM_PUSH="${ENABLE_FCM_PUSH:-true}"

firebase_android_define_keys=(
  FIREBASE_ANDROID_API_KEY
  FIREBASE_ANDROID_APP_ID
  FIREBASE_ANDROID_MESSAGING_SENDER_ID
  FIREBASE_ANDROID_PROJECT_ID
  FIREBASE_ANDROID_STORAGE_BUCKET
  FIREBASE_ANDROID_AUTH_DOMAIN
  FIREBASE_ANDROID_MEASUREMENT_ID
  FIREBASE_ANDROID_CLIENT_ID
)

has_firebase_android_runtime_defines() {
  [[ -n "${FIREBASE_ANDROID_API_KEY:-}" ]] &&
    [[ -n "${FIREBASE_ANDROID_APP_ID:-}" ]] &&
    [[ -n "${FIREBASE_ANDROID_MESSAGING_SENDER_ID:-}" ]] &&
    [[ -n "${FIREBASE_ANDROID_PROJECT_ID:-}" ]]
}

append_firebase_android_defines() {
  local key
  for key in "${firebase_android_define_keys[@]}"; do
    if [[ -n "${!key:-}" ]]; then
      EXTRA_DEFINES+=(--dart-define="$key=${!key}")
    fi
  done
}

EXTRA_DEFINES=()
if [[ "$ENABLE_FCM_PUSH" == "true" ]]; then
  if [[ ! -f android/app/google-services.json ]] &&
    ! has_firebase_android_runtime_defines; then
    echo "[ERROR] ENABLE_FCM_PUSH=true but Firebase Android config is missing."
    echo "        Add android/app/google-services.json or export FIREBASE_ANDROID_API_KEY,"
    echo "        FIREBASE_ANDROID_APP_ID, FIREBASE_ANDROID_MESSAGING_SENDER_ID,"
    echo "        and FIREBASE_ANDROID_PROJECT_ID before running."
    echo "        For websocket/local-only testing: ENABLE_FCM_PUSH=false ./scripts/run_android_device.sh ..."
    exit 1
  fi
  append_firebase_android_defines
fi

if [[ -n "$HOST_ORIGIN" ]]; then
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
    --dart-define=BACKEND_HOST="$HOSTPORT"
    --dart-define=TENANT_REALM="$TENANT_REALM"
    --dart-define=AUTH_BASE_URL="${ORIGIN}/${TENANT_REALM}/auth"
    --dart-define=CHAT_BASE_URL="${ORIGIN}/${TENANT_REALM}/chat"
    --dart-define=CHAT_WS_BASE_URL="${WS_SCHEME}://${HOSTPORT}/${TENANT_REALM}/chat"
    --dart-define=MINA_SIGNALING_WS_URL="${WS_SCHEME}://${HOSTPORT}/${TENANT_REALM}/ws"
    --dart-define=MINA_NOTIFICATION_WS_URL="${WS_SCHEME}://${HOSTPORT}/${TENANT_REALM}/notifications/ws"
    --dart-define=NOTIFICATION_API_BASE_URL="${ORIGIN}/${TENANT_REALM}/notifications"
    --dart-define=ADMIN_BASE_URL="${ORIGIN}/${TENANT_REALM}/admin"
  )
  HOST_IP="$HOSTPORT"
else
  if [ -n "${BACKEND_HOST:-}" ]; then
    HOST_IP="$BACKEND_HOST"
  elif [ -n "$DEFAULT_BACKEND_HOST" ] && can_reach_host "$DEFAULT_BACKEND_HOST" 7101; then
    HOST_IP="$DEFAULT_BACKEND_HOST"
  else
    HOST_IP="$AUTO_DETECTED_IP"
  fi
  if [ -z "$HOST_IP" ]; then
    echo "[ERROR] Could not determine host IP. Set BACKEND_HOST manually."
    exit 1
  fi

  # Direct microservice ports (dev/local).
  EXTRA_DEFINES+=(
    --dart-define=BACKEND_HOST="$HOST_IP"
    --dart-define=TENANT_REALM="$TENANT_REALM"
    --dart-define=AUTH_BASE_URL="http://${HOST_IP}:7101"
    --dart-define=CHAT_BASE_URL="http://${HOST_IP}:7109"
    --dart-define=CHAT_WS_BASE_URL="ws://${HOST_IP}:7109"
    --dart-define=MINA_SIGNALING_WS_URL="${MINA_SIGNALING_WS_URL:-ws://${HOST_IP}:2443/ws}"
    --dart-define=MINA_NOTIFICATION_WS_URL="${MINA_NOTIFICATION_WS_URL:-ws://${HOST_IP}:7112/api/notifications/ws}"
    --dart-define=NOTIFICATION_API_BASE_URL="${NOTIFICATION_API_BASE_URL:-http://${HOST_IP}:7112/api/notifications}"
  )
fi

echo "[INFO] Using device: $DEVICE_ID"
echo "[INFO] Using host IP: $HOST_IP"
if [ -n "$AUTO_DETECTED_IP" ]; then
  echo "[INFO] Auto-detected IP: $AUTO_DETECTED_IP"
fi
if [ -n "$DEFAULT_BACKEND_HOST" ]; then
  echo "[INFO] Default BACKEND_HOST: $DEFAULT_BACKEND_HOST"
fi
echo "[INFO] TENANT_REALM=$TENANT_REALM CHAT_USER_ID_SOURCE=$CHAT_USER_ID_SOURCE ENABLE_FCM_PUSH=$ENABLE_FCM_PUSH"

# ─── Native (Rust) Build Step ───
if [ "${SKIP_NATIVE_BUILD:-false}" != "true" ]; then
  echo "[INFO] Checking native Rust dependencies for live_bg..."
  LIVE_BG_DIR="$(cd "$ROOT_DIR/../../../../Modules/live_bg" && pwd)"
  NATIVE_DIR="$LIVE_BG_DIR/native"
  
  if [ -d "$NATIVE_DIR" ]; then
    # Ensure cargo-ndk is installed
    if ! cargo ndk --version >/dev/null 2>&1; then
      echo "[INFO] Installing cargo-ndk..."
      # Add ~/.cargo/bin to PATH for the current session
      export PATH="$HOME/.cargo/bin:$PATH"
      cargo install cargo-ndk
    fi
    export PATH="$HOME/.cargo/bin:$PATH"
    
    # Auto-detect latest valid NDK
    if [ -z "${ANDROID_NDK_HOME:-}" ]; then
      echo "[INFO] Auto-detecting NDK..."
      # Search common locations
      NDK_BASE="/Users/bhangun/Library/Android/sdk/ndk"
      # Find latest non-empty NDK directory
      for ndk_dir in $(ls -r "$NDK_BASE" 2>/dev/null); do
        if [ -f "$NDK_BASE/$ndk_dir/source.properties" ]; then
          export ANDROID_NDK_HOME="$NDK_BASE/$ndk_dir"
          echo "[INFO] Found valid NDK at $ANDROID_NDK_HOME"
          break
        fi
      done
    fi

    if [ -z "${ANDROID_NDK_HOME:-}" ]; then
       echo "[ERROR] No valid Android NDK found. Please install NDK via Android Studio."
       exit 1
    fi
    
    # Ensure rustup is installed
    if ! command -v rustup >/dev/null 2>&1; then
      echo "[ERROR] 'rustup' not found. You need the official Rust toolchain to cross-compile for Android."
      echo "        Please install it by running: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
      echo "        Then restart your terminal and run this script again."
      exit 1
    fi
    
    # Ensure Android targets are added
    echo "[INFO] Ensuring Rust Android targets..."
    rustup target add aarch64-linux-android
    
    echo "[INFO] Building native Rust library for Android (arm64-v8a)..."
    (
      cd "$NATIVE_DIR"
      cargo ndk -t arm64-v8a build --release
    )
    
    # Copy to jniLibs
    JNILIBS_DIR="$LIVE_BG_DIR/android/src/main/jniLibs/arm64-v8a"
    mkdir -p "$JNILIBS_DIR"
    cp "$NATIVE_DIR/target/aarch64-linux-android/release/liblive_bg_native.so" "$JNILIBS_DIR/"
    echo "[INFO] Native library deployed to $JNILIBS_DIR"
  else
    echo "[WARNING] Native directory not found at $NATIVE_DIR. Skipping Rust build."
  fi
fi
# ──────────────────────────────

flutter run -d "$DEVICE_ID" \
  "${EXTRA_DEFINES[@]}" \
  --dart-define=ENABLE_FCM_PUSH="$ENABLE_FCM_PUSH" \
  --dart-define=CHAT_USER_ID_SOURCE="$CHAT_USER_ID_SOURCE"
