#!/usr/bin/env bash
set -e

# ==============================================================================
# Alhambra Vibe Coder & Dual-Backend Development Launcher
# ==============================================================================
# Usage:
#   ./run-dev.sh [OPTIONS]
#
# Options:
#   --gui-only       Launch only the Flutter Desktop GUI
#   --backend-only   Launch only the Gollek & Alhambra backend servers
#   --help           Show this help message
#
# Configuration (.env or Environment Variables):
#   GOLLEK_SOURCE_PATH   Path to Gollek repository (default: auto-detected)
#   ALHAMBRA_SOURCE_PATH   Path to Alhambra repository (default: auto-detected)
#   ANDALUS_SOURCE_PATH   Path to Andalus platform root (default: auto-detected)
#   GGUF_CONTEXT_SIZE    Gollek context window size (default: 8192)
# ==============================================================================

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"

# ── Load .env files (Hierarchy: workspace .env -> local .env -> .env.local) ───
load_env_file() {
  local env_file="$1"
  if [ -f "$env_file" ]; then
    echo -e "• Loaded environment from: ${CYAN}${env_file}${NC}"
    while IFS= read -r line || [ -n "$line" ]; do
      line="$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
      if [[ -z "$line" || "$line" =~ ^# ]]; then
        continue
      fi
      # Strip quotes if present
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
load_env_file "$SCRIPT_DIR/.env.development"
load_env_file "$SCRIPT_DIR/.env.local"

# Parse Flags
GUI_ONLY=false
BACKEND_ONLY=false

for arg in "$@"; do
  case "$arg" in
    --gui-only)
      GUI_ONLY=true
      ;;
    --backend-only)
      BACKEND_ONLY=true
      ;;
    --help|-h)
      echo "Usage: ./run-dev.sh [--gui-only] [--backend-only]"
      exit 0
      ;;
  esac
done

echo -e "${CYAN}${BOLD}"
echo "=================================================================="
echo "  🚀 ALHAMBRA STUDIO - DEVELOPMENT RUNTIME LAUNCHER"
echo "=================================================================="
echo -e "${NC}"

# 1. Resolve Source Paths
export ALHAMBRA_MODE="development"
export GGUF_CONTEXT_SIZE="${GGUF_CONTEXT_SIZE:-8192}"

if [ -z "$ANDALUS_SOURCE_PATH" ]; then
  if [ -d "$WORKSPACE_ROOT/Families" ]; then
    export ANDALUS_SOURCE_PATH="$WORKSPACE_ROOT"
  else
    export ANDALUS_SOURCE_PATH="$(pwd)"
  fi
fi

if [ -z "$GOLLEK_SOURCE_PATH" ]; then
  if [ -d "$ANDALUS_SOURCE_PATH/Families/gollek" ]; then
    export GOLLEK_SOURCE_PATH="$ANDALUS_SOURCE_PATH/Families/gollek"
  elif [ -d "$ANDALUS_SOURCE_PATH/gollek" ]; then
    export GOLLEK_SOURCE_PATH="$ANDALUS_SOURCE_PATH/gollek"
  fi
fi

if [ -z "$ALHAMBRA_SOURCE_PATH" ]; then
  if [ -d "$ANDALUS_SOURCE_PATH/Projects/Andalus-Agents/AlhambraCoder" ]; then
    export ALHAMBRA_SOURCE_PATH="$ANDALUS_SOURCE_PATH/Projects/Andalus-Agents/AlhambraCoder"
  elif [ -d "$ANDALUS_SOURCE_PATH/Projects/Andalus-Agents/Alhambra" ]; then
    export ALHAMBRA_SOURCE_PATH="$ANDALUS_SOURCE_PATH/Projects/Andalus-Agents/Alhambra"
  elif [ -d "$ANDALUS_SOURCE_PATH/Andalus-Projects/Andalus-Agents/AlhambraCoder" ]; then
    export ALHAMBRA_SOURCE_PATH="$ANDALUS_SOURCE_PATH/Andalus-Projects/Andalus-Agents/AlhambraCoder"
  elif [ -d "$ANDALUS_SOURCE_PATH/Andalus-Projects/Andalus-Agents/Alhambra" ]; then
    export ALHAMBRA_SOURCE_PATH="$ANDALUS_SOURCE_PATH/Andalus-Projects/Andalus-Agents/Alhambra"
  fi
fi

echo -e "• Configuration & Paths:"
echo -e "  - Workspace Root:     ${GREEN}${ANDALUS_SOURCE_PATH}${NC}"
echo -e "  - Gollek Inference:   ${GREEN}${GOLLEK_SOURCE_PATH:-Not Set (will probe)}${NC}"
echo -e "  - Alhambra Agent:       ${GREEN}${ALHAMBRA_SOURCE_PATH:-Not Set (will probe)}${NC}"
echo -e "  - Mode:               ${CYAN}${ALHAMBRA_MODE}${NC}"
echo -e "  - Context Window:     ${CYAN}${GGUF_CONTEXT_SIZE}${NC}"
echo ""

# 2. Check Java & Toolchain
if [ -z "$JAVA_HOME" ] && command -v /usr/libexec/java_home >/dev/null 2>&1; then
  JAVA_25_HOME="$(/usr/libexec/java_home -v 25 2>/dev/null || true)"
  if [ -n "$JAVA_25_HOME" ]; then
    export JAVA_HOME="$JAVA_25_HOME"
  else
    export JAVA_HOME="$(/usr/libexec/java_home 2>/dev/null || true)"
  fi
fi

if [ -n "$JAVA_HOME" ] && [ -d "$JAVA_HOME/bin" ]; then
  export PATH="$JAVA_HOME/bin:$PATH"
fi

if command -v java >/dev/null 2>&1; then
  JAVA_VER=$(java -version 2>&1 | head -n 1)
  echo -e "• Java Environment:   ${GREEN}${JAVA_VER}${NC}"
else
  echo -e "• Java Environment:   ${YELLOW}⚠️  Java not found in PATH${NC}"
fi

# 3. Start Backend Services (if not gui-only)
PIDS=()

if [ "$GUI_ONLY" = false ]; then
  echo -e "\n${BLUE}=== Starting Dual-Substrate Development Backends ===${NC}"

  # 3a. Start Gollek Inference Engine
  GOLLEK_LAUNCHER="$ALHAMBRA_SOURCE_PATH/Community/Backend/start-gollek.sh"
  if [ -f "$GOLLEK_LAUNCHER" ]; then
    echo -e "${GREEN}[1/2] Launching Gollek Inference Server (:8080 / :9131)...${NC}"
    bash "$GOLLEK_LAUNCHER" &
    PIDS+=($!)
  fi

  # 3b. Start Alhambra Agent Substrate
  ALHAMBRA_LAUNCHER="$ALHAMBRA_SOURCE_PATH/Community/Backend/alhambra-api/start-local.sh"
  if [ -f "$ALHAMBRA_LAUNCHER" ]; then
    echo -e "${GREEN}[2/2] Launching Alhambra Agent & Substrate Backend (:8085 / :9000)...${NC}"
    bash "$ALHAMBRA_LAUNCHER" &
    PIDS+=($!)
  fi

  if [ "$BACKEND_ONLY" = true ]; then
    echo -e "\n${CYAN}Backends running in foreground. Press Ctrl+C to terminate.${NC}"
    trap "kill ${PIDS[*]} 2>/dev/null || true; exit" SIGINT SIGTERM EXIT
    wait
    exit 0
  fi
fi

# 4. Launch Flutter Desktop GUI
if [ "$BACKEND_ONLY" = false ]; then
  echo -e "\n${BLUE}=== Launching Alhambra Flutter Studio Desktop ===${NC}"
  if [ -d "$SCRIPT_DIR/alhambra" ]; then
    cd "$SCRIPT_DIR/alhambra"
  else
    cd "$SCRIPT_DIR/alhambra_ui"
  fi
  
  PLATFORM_TARGET="macos"
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    PLATFORM_TARGET="linux"
  fi

  flutter run -d "$PLATFORM_TARGET"
fi

# Cleanup background processes
if [ ${#PIDS[@]} -gt 0 ]; then
  echo -e "\n${YELLOW}Shutting down background services...${NC}"
  kill "${PIDS[@]}" 2>/dev/null || true
fi

echo -e "${GREEN}Done!${NC}"
