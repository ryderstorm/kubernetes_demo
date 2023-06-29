#!/bin/bash

# =================================================================================================
# This script installs k3s onto your local machine.
# It also installs the kubernetes dashboard and creates a user for accessing the dashboard.
# =================================================================================================

set -e

# Import helper library
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "$SCRIPT_DIR/../../lib/bash_helpers.sh"

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


k3s_running() {
  k3s kubectl get nodes && return 0 || return 1
}

dashboard_installed() {
  k3s kubectl get ns kubernetes-dashboard && return 0 || return 1
}

install_dashboard() {
  log_info "Installing KubernetesDashboard in k3s..."
  # from: https://docs.k3s.io/installation/kube-dashboard#deploying-the-kubernetes-dashboard
  github_url=https://github.com/kubernetes/dashboard/releases
  version_kube_dashboard=$(curl -w '%{url_effective}' -I -L -s -S ${github_url}/latest -o /dev/null | sed -e 's|.*/||')
  k3s kubectl create -f https://raw.githubusercontent.com/kubernetes/dashboard/${version_kube_dashboard}/aio/deploy/recommended.yaml
  log_success "Successfully installed the Kubernetes dashboard in k3s."
}

admin_user_exists() {
  k3s kubectl get sa admin-user -n kubernetes-dashboard && return 0 || return 1
}

generate_token() {
  spacer
  log_info "Generating token for user in k3s: admin-user"
  token=$(k3s kubectl -n kubernetes-dashboard create token admin-user)
  if [ $? -eq 0 ]; then
    echo "$token" | xclip -selection clipboard
    log_success "Created token for user in k3s: admin-user"
    echo -e "Token for admin-user:${BLUE}\n$token${NC}"
    echo -e "The token has been copied to your clipboard."
  else
    log_error "Failed to create token for user in k3s: admin-user"
    exit 1
  fi
}

start_proxy() {
  spacer
  # find any existing processes that are listening on port 8001 and kill them
  log_info "Stopping any existing proxy for k3s..."
  sudo kill "$(sudo lsof -t -i:8001)" || true

  log_info "Starting proxy for k3s..."
  k3s kubectl proxy &>/dev/null & disown
  log_success "Proxy for k3s is running."
}

# =================================================================================================
# Main Script
# =================================================================================================

spacer
echo -e "${WHITE}This script will install k3s onto your local machine.${NC}"
echo -e "${WHITE}You will be prompted for your sudo password during the installation process.${NC}"
spacer
if ! prompt_yes_no "Do you wish to continue?"; then
  spacer
  echo -e "${YELLOW}Exiting...${NC}"
  exit 0
fi

if k3s_installed; then
  spacer
  log_info "k3s is already installed."
  echo -e "\n${WHITE}If you wish to reinstall k3s, please uninstall it with the following command:${NC}"
  echo -e "${BLUE}/usr/local/bin/k3s-uninstall.sh${NC}"
  echo -e "\n${WHITE}And run this script again.${NC}"
  spacer
  if ! prompt_yes_no "Do you wish to continue and install the dashboard?"; then
    spacer
    echo -e "${YELLOW}Exiting...${NC}"
    exit 0
  fi
else
  install_k3s
  setup_kubeconfig
fi

if ! k3s_running; then
  log_error "k3s is not running. Please ensure k3s is installed and running and then run this script again."
  spacer
  echo -e "${RED}Exiting...${NC}"
  exit 1
fi

if dashboard_installed; then
  spacer
  echo -e "${WHITE}The Kubernetes dashboard is already installed.${NC}"
else
  install_dashboard
fi

if ! admin_user_exists; then
  log_info "Creating admin-user in k3s..."
  # from: https://docs.k3s.io/installation/kube-dashboard#dashboard-rbac-configuration
  if ! run_command "k3s kubectl create -f $SCRIPT_DIR/../configs/dashboard.admin-user.yml -f $SCRIPT_DIR/../configs/dashboard.admin-user-role.yml"; then
    log_error "Failed to create user in k3s: admin-user"
    exit 1
  fi
fi

generate_token
log_success "Dashboard installed user created."
start_proxy
spacer
echo -e "To access the Kubernetes dashboard, go to the URL below in your browser and enter the token when prompted.\n\n${BLUE}\nhttp://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/${NC}"
