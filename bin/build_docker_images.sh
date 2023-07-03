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
  image_name="$DOCKER_REPOSITORY-$app_name"
  git_sha=$(git rev-parse --short HEAD)
  log_info "Building and pushing Docker image for ${BLUE}$app_name${NC} to ${CYAN}$image_name${NC} with tag ${YELLOW}$git_sha${NC}..."
  run_command "echo $git_sha > $app_dir/VERSION"
  # write the current timestamp to the TIMESTAMP file
  run_command "echo $(date +%s) > $app_dir/TIMESTAMP"
  run_command "docker build -t $image_name:$git_sha -t $image_name:latest $app_dir"
  run_command "docker push $image_name"
done

spacer
log_success "Successfully built and pushed Docker images for all demo apps."
