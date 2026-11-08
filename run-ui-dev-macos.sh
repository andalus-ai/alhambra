#!/bin/bash
set -e

# Full stack dev launcher for alhambra_gui
# Usage: ./run-dev-macos.sh [--gui-only]

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

GUI_DIR="alhambra_ui"
PLATFORM_DIR="$(cd "$GUI_DIR" && pwd)"
BACKEND_DIR="$PLATFORM_DIR/Andalus-Projects/Andalus-Agents/Alhambra/Backend/alhambra-api"
INFRA_DIR="$PLATFORM_DIR/Andalus-Projects/Andalus-Agents"

if [[ "$1" == "--gui-only" ]]; then
  echo -e "${YELLOW}[gui-only] Skipping backend startup...${NC}"
else
  echo -e "${BLUE}=== Starting Backend Infrastructure ===${NC}"

  # 1. Docker
  echo -e "${GREEN}[1/2] Starting Docker (PostgreSQL + Redis)...${NC}"
  docker-compose -f "$INFRA_DIR/Alhambra/Backend/docker-compose.yml" up -d

  # 2. Quarkus backend
  echo -e "${GREEN}[2/2] Starting Quarkus (REST:8086, gRPC:9000)...${NC}"
  cd "$BACKEND_DIR"
  mvn quarkus:dev -Dquarkus.http.port=8086 &
  QUARKUS_PID=$!
  cd "$GUI_DIR"

  echo -e "${YELLOW}Waiting 15s for Quarkus to boot...${NC}"
  sleep 15
fi

echo -e "\n${GREEN}Launching Alhambra GUI on macOS...${NC}"
flutter run -d macos

if [[ -n "$QUARKUS_PID" ]]; then
  echo -e "\n${BLUE}Shutting down Quarkus (PID $QUARKUS_PID)...${NC}"
  kill $QUARKUS_PID 2>/dev/null || true
fi

echo -e "${GREEN}Done!${NC}"