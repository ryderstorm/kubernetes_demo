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

# =================================================================================================
# Helper Functions
# =================================================================================================

k3s_installed() {
  k3s --version 2>/dev/null && return 0 || return 1
}

install_k3s() {
  log_info "Installing k3s..."
  # from: https://rancher.com/docs/k3s/latest/en/installation/install-options/
  # the --write-kubeconfig-mode 644 flag allows k3s to be run as a non-root user
  run_command "curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC='--write-kubeconfig-mode 644 --disable=traefik' sh -"
  log_success "Successfully installed k3s."
  log_info "Configuring kubectl to work with new k3s cluster..."
  run_command "cp /etc/rancher/k3s/k3s.yaml $SCRIPT_DIR/../tmp/k3s.yaml"
  run_command "export KUBECONFIG=$SCRIPT_DIR/../tmp/k3s.yaml"
  run_command "kubectl config rename-context default k3s-local"
}

# =================================================================================================
# Main Script
# =================================================================================================

spacer
echo -e "${WHITE}This script will install k3s onto your local machine.${NC}"
echo -e "${WHITE}You will be prompted for your sudo password during the installation process.${NC}"
spacer
if [ "$1" != "confirm" ] && ! prompt_yes_no "Do you wish to continue?"; then
  graceful_exit 0
fi

if k3s_installed; then
  spacer
  log_info "k3s is already installed."
  echo -e "\n${WHITE}If you wish to reinstall k3s, please uninstall it with the following command:${NC}"
  echo -e "${BLUE}/usr/local/bin/k3s-uninstall.sh${NC}"
  echo -e "\n${WHITE}And run this script again.${NC}"
  spacer
  if [ "$1" != "confirm" ] && ! prompt_yes_no "Do you wish to continue and reapply the cluster configuration?"; then
    graceful_exit 0
  fi
else
  install_k3s
fi

set_up_k8s_cluster
spacer
echo -e "\nTo use kubectl with k3s you must run:\n${BLUE}export KUBECONFIG=tmp/k3s.yaml${NC}\n"
echo -e "To test that it is working, run:\n${BLUE}kubectl get nodes${NC}\n"

# Install Traefik and the demo apps
k8s_install_traefik
k8s_install_demo_apps

spacer

log_success "Cluster apps are installed and ready to use."
log_info "You can access apps in the cluster at the following URLs:"
display_app_urls
graceful_exit
