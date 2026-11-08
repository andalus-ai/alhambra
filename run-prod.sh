#!/usr/bin/env bash
set -e

# ==============================================================================
# Alhambra Vibe Coder - Production Runtime Launcher
# ==============================================================================
# In production mode, Alhambra Vibe Coder runs as a standalone professional app.
# The background engine automatically provisions binaries from GitHub Releases:
#   • https://github.com/bhangun/alhambra
#   • https://github.com/bhangun/andalus
#   • https://github.com/bhangun/gollek
# ==============================================================================

GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"

# ── Load .env files (Hierarchy: workspace .env -> local .env -> .env.production) ───
load_env_file() {
  local env_file="$1"
  if [ -f "$env_file" ]; then
    echo -e "• Loaded environment from: ${CYAN}${env_file}${NC}"
    while IFS= read -r line || [ -n "$line" ]; do
      line="$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
      if [[ -z "$line" || "$line" =~ ^# ]]; then
        continue
      fi
      key=$(echo "$line" | cut -d '=' -f 1 | xargs)
      val=$(echo "$line" | cut -d '=' -f 2- | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
      if [ -n "$key" ]; then
        export "$key=$val"
      fi
    done < "$env_file"
  fi
}

load_env_file "$WORKSPACE_ROOT/.env"
load_env_file "$SCRIPT_DIR/.env"
load_env_file "$SCRIPT_DIR/.env.production"
load_env_file "$SCRIPT_DIR/.env.local"

echo -e "${CYAN}${BOLD}"
echo "=================================================================="
echo "  ⚡ ALHAMBRA STUDIO - PRODUCTION RUNTIME"
echo "=================================================================="
echo -e "${NC}"

export ALHAMBRA_MODE="production"

cd "$SCRIPT_DIR/alhambra_ui"

PLATFORM_TARGET="macos"
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  PLATFORM_TARGET="linux"
fi

echo -e "• Running in Production Mode (${PLATFORM_TARGET})"
echo -e "• Launching standalone release bundle..."

flutter run --release -d "$PLATFORM_TARGET"
