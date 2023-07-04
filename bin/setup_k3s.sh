#!/bin/bash

# =================================================================================================
# This script installs k3s onto your local machine.
# It also installs the kubernetes dashboard and creates a user for accessing the dashboard.
# =================================================================================================

set -e

# Import helper library
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "$SCRIPT_DIR/../lib/set_envs.sh"
source "$SCRIPT_DIR/../lib/helpers.sh"
trap trap_cleanup ERR SIGINT SIGTERM

declare -A REQUIRED_APPS=(
  ["jq"]="jq --version ||| https://stedolan.github.io/jq/download/"
  ["kubectl"]="kubectl version --client ||| https://kubernetes.io/docs/tasks/tools/#kubectl"
)
export REQUIRED_APPS
check_installed_apps

export RUNNING_K3S=true

if k3s_installed && k8s_running; then
  k3s_show_reinstall_warning
else
  install_k3s
fi

set_up_k8s_cluster
spacer

# Install Traefik and the demo apps
k8s_install_traefik
k8s_install_demo_apps

spacer

log_success "Cluster apps are installed and ready to use."
log_info "You can access apps in the cluster at the following URLs:"
traefik_report_access_points
log_info "To use kubectl with k3s you must run:\n${BLUE}export KUBECONFIG=tmp/k3s.yaml${NC}\n"
log_info "To test that it is working, run:\n${BLUE}kubectl get nodes${NC}\n"
k8s_set_up_dashboard_proxy
graceful_exit
