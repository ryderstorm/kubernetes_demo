#!/bin/bash

# =================================================================================================
# This script builds and pushes the Docker images for the demo apps to the Docker registry.
# =================================================================================================

set -e

# Import helper library
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "$SCRIPT_DIR/../lib/set_envs.sh"
source "$SCRIPT_DIR/../lib/helpers.sh"
trap trap_cleanup ERR SIGINT SIGTERM

# =================================================================================================
# Main Script
# =================================================================================================

for app_dir in "$SCRIPT_DIR/../apps"/*; do
  spacer
  app_name=$(basename "$app_dir")
  log_info "Building and pushing Docker image for ${BLUE}$app_name${NC} to ${CYAN}$DOCKER_REPOSITORY${NC}..."
  run_command "docker build -t '$app_name' '$app_dir'"
  run_command "docker tag '$app_name' '$DOCKER_REPOSITORY/$app_name:$(git rev-parse --short HEAD)'"
  run_command "docker tag '$app_name' '$DOCKER_REPOSITORY/$app_name:latest'"
  run_command "docker push '$DOCKER_REPOSITORY:$app_name'"
done

spacer
log_success "Successfully built and pushed Docker images for all demo apps."
