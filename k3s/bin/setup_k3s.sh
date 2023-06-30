#!/bin/bash

# =================================================================================================
# This script installs k3s onto your local machine.
# It also installs the kubernetes dashboard and creates a user for accessing the dashboard.
# =================================================================================================

set -e

# Import helper library
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "$SCRIPT_DIR/../../lib/set_envs.sh"
source "$SCRIPT_DIR/../../lib/helpers.sh"

export K3S=true

# =================================================================================================
# Helper Functions
# =================================================================================================

k3s_installed() {
  k3s --version && return 0 || return 1
}

install_k3s() {
  log_info "Installing k3s..."
  # from: https://rancher.com/docs/k3s/latest/en/installation/install-options/
  # the --write-kubeconfig-mode 644 flag allows k3s to be run as a non-root user
  curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--write-kubeconfig-mode 644" sh -
  log_success "Successfully installed k3s."
}

setup_kubeconfig() {
  spacer
  log_info "Setting up kubeconfig..."
  # from:
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
  echo -e "\nThis window is now configured to use k3s. To use k3s in other windows, you must first run:\n${BLUE}export KUBECONFIG=/etc/rancher/k3s/k3s.yaml${NC}\n"
  echo -e "To test that k3s is working, run:\n${BLUE}kubectl get nodes${NC}\n"
  echo -e "Press ${BLUE}Enter${NC} to continue."
  read -r
}

# =================================================================================================
# Main Script
# =================================================================================================

spacer
echo -e "${WHITE}This script will install k3s onto your local machine.${NC}"
echo -e "${WHITE}You will be prompted for your sudo password during the installation process.${NC}"
spacer
if ! prompt_yes_no "Do you wish to continue?"; then
  graceful_exit 0
fi

if k3s_installed; then
  spacer
  log_info "k3s is already installed."
  echo -e "\n${WHITE}If you wish to reinstall k3s, please uninstall it with the following command:${NC}"
  echo -e "${BLUE}/usr/local/bin/k3s-uninstall.sh${NC}"
  echo -e "\n${WHITE}And run this script again.${NC}"
  spacer
  if ! prompt_yes_no "Do you wish to continue and install the dashboard?"; then
    graceful_exit 0
  fi
else
  install_k3s
  setup_kubeconfig
fi

if ! k8s_running; then
  log_error "k3s is not running. Please ensure k3s is installed and running and then run this script again."
  graceful_exit 1
fi

if ! k8s_dashboard_installed && ! k8s_install_dashboard; then
  log_error "Failed to install dashboard."
  graceful_exit 1
fi

if ! k8s_admin_user_exists && ! k8s_create_admin_user; then
  log_error "Failed to create admin user."
  graceful_exit 1
fi

k8_generate_token_for_admin_user
log_success "Dashboard installed and admin user created."
k8s_start_proxy
k8s_show_dashboard_access_instructions
