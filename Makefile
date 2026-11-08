.PHONY: help build-backend run-backend build-gui run-gui clean

# Environment Paths
GRAALVM_HOME ?= /Library/Java/JavaVirtualMachines/graalvm-25.jdk/Contents/Home
export JAVA_HOME = $(GRAALVM_HOME)
export PATH := $(JAVA_HOME)/bin:$(PATH)

# Project Paths
BACKEND_DIR = Backend
GUI_DIR = alhambra_gui

help: ## Show this help message
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

build-backend: ## Build the Quarkus Backend (Uber-JAR)
	@echo "Building Alhambra Backend..."
	@cd $(BACKEND_DIR) && mvn clean package -Dmaven.test.skip=true

run-backend: ## Run the Quarkus Backend in Dev Mode
	@echo "Running Alhambra Backend in Dev Mode..."
	@cd $(BACKEND_DIR)/alhambra-api && mvn quarkus:dev

run-backend-prod: ## Run the packaged Quarkus Backend (must run build-backend first)
	@echo "Running Packaged Alhambra Backend..."
	@java -jar $(BACKEND_DIR)/alhambra-api/target/quarkus-app/quarkus-run.jar

build-gui: ## Build the Flutter macOS app
	@echo "Building Alhambra GUI (macOS)..."
	@cd $(GUI_DIR) && flutter build macos

run-gui: ## Run the Flutter GUI app locally
	@echo "Running Alhambra GUI..."
	@cd $(GUI_DIR) && flutter run -d macos

clean: ## Clean build artifacts
	@echo "Cleaning backend and GUI..."
	@cd $(BACKEND_DIR) && mvn clean
	@cd $(GUI_DIR) && flutter clean
