#!/bin/bash

# =================================================================================================
# This script installs the demo apps onto your current kubernetes cluster.
# =================================================================================================

set -e

# Import helper library
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "$SCRIPT_DIR/../lib/set_envs.sh"
source "$SCRIPT_DIR/../lib/helpers.sh"

# =================================================================================================
# Main Script
# =================================================================================================

# Set up namespaces
log_info "Setting up namespaces..."
namespace_file="$SCRIPT_DIR/../kubernetes/deployments/misc/namespaces.yaml"
command="kubectl apply -f $namespace_file"
run_command "$command"

# Install Helm chart for Traefik
log_info "Installing Traefik..."
values_file="$SCRIPT_DIR/../kubernetes/helm/traefik-values.yaml"
command="helm upgrade --install --values=$values_file -n traefik traefik traefik/traefik"
run_command "$command"
dashboard_file="$SCRIPT_DIR/../kubernetes/deployments/traefik/traefik-dashboard.yaml"
command="kubectl apply -f $dashboard_file"
run_command "$command"
log_success "Successfully installed Traefik."

# Install sample apps via kubectl apply
log_info "Installing demo apps..."
demo_apps_folder="$SCRIPT_DIR/../kubernetes/deployments/demo_apps"
command="kubectl apply -f $demo_apps_folder"
run_command "$command"
log_success "Successfully installed demo apps."

# get the traefik load balancer address
printf "Waiting for Traefik load balancer to be ready..."
TIMEOUT=60
START_TIME=$(date +%s)
while true; do
  CURRENT_TIME=$(date +%s)
  ELAPSED_TIME=$((CURRENT_TIME - START_TIME))
  if [ $ELAPSED_TIME -gt $TIMEOUT ]; then
    spacer
    log_error "Timed out waiting for Traefik load balancer to be ready."
    graceful_exit 1
  fi
  if traefik_endpoint_responding; then
    echo ""
    break
  fi
  printf "."
  sleep 1
done

# Report results
log_success "Cluster apps are installed and ready to use."
log_info "You can access apps in the cluster at the following URLs:"
display_app_urls
graceful_exit
