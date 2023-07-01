#!/bin/bash

# =================================================================================================
# This script installs the demo apps onto your current kubernetes cluster.
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

# Set up namespaces

# Install Helm chart for Traefik
log_info "Installing Traefik..."
run_command "helm repo add traefik https://helm.traefik.io/traefik"
run_command "helm repo update"
values_file="$SCRIPT_DIR/../kubernetes/helm/traefik-values.yaml"
command="helm upgrade --install --create-namespace --values=$values_file -n traefik traefik traefik/traefik"
run_command "$command"
dashboard_file="$SCRIPT_DIR/../kubernetes/deployments/traefik/traefik-dashboard.yaml"
command="kubectl apply -f $dashboard_file"
run_command "$command"
if ! k8s_wait_for_pod "traefik" "app.kubernetes.io/name=traefik" && ! wait_for_traefik_endpoint; then
  log_error "Failed to install Traefik."
  graceful_exit 1
fi
log_success "Successfully installed Traefik. Please try running this script again."

# Install sample apps via kubectl apply
log_info "Installing demo apps..."
namespace_file="$SCRIPT_DIR/../kubernetes/deployments/misc/namespaces.yaml"
command="kubectl apply -f $namespace_file"
run_command "$command"
demo_apps_folder="$SCRIPT_DIR/../kubernetes/deployments/demo_apps"
command="kubectl apply -f $demo_apps_folder"
run_command "$command"
if ! k8s_wait_for_pod "demo-apps" "app=nginx-hello"; then
  log_error "Failed to install demo apps. Please try running this script again."
  graceful_exit 1
fi
log_success "Successfully installed demo apps."

spacer

log_success "Cluster apps are installed and ready to use."
log_info "You can access apps in the cluster at the following URLs:"
display_app_urls
graceful_exit
