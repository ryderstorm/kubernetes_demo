#!/bin/bash

# =================================================================================================
# This script uses Terraform, Helm, and kubectl to set up a Kubernetes cluster on a cloud service and deploy the demo apps to it.
# =================================================================================================

set -e

# Start timer
START_TIME=$(date +%s)

# Import helper libriaries
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "$SCRIPT_DIR/../lib/set_envs.sh"
source "$SCRIPT_DIR/../lib/helpers.sh"

trap trap_cleanup ERR SIGINT SIGTERM

# Check for required apps
declare -A REQUIRED_APPS=(
  ["awscli"]="aws --version ||| https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html#getting-started-install-instructions"
  ["dig"]="dig -v ||| https://www.isc.org/bind/"
  ["helm"]="helm version --client ||| https://helm.sh/docs/intro/install/"
  ["jq"]="jq --version ||| https://stedolan.github.io/jq/download/"
  ["kubectl"]="kubectl version --client ||| https://kubernetes.io/docs/tasks/tools/#kubectl"
  ["terraform"]="terraform version ||| https://learn.hashicorp.com/tutorials/terraform/install-cli"
)
export REQUIRED_APPS
check_installed_apps

# Handle if the user wants to skip the confirmation prompt
if [ "$1" == "confirm" ]; then
  export USER_CONFIRMED=true
fi

# =================================================================================================
# Main Script
# =================================================================================================

prompt_for_cluster_type

spacer
# If the cluster type is k3s
if [ "$CLUSTER_TYPE" == "k3s" ]; then
  # Use k3s to create the cluster
  if k3s_installed && k8s_running; then
    k3s_show_reinstall_warning
  else
    install_k3s
  fi
else
  # Use Terraform to create the cluster
  log_info "Initializing Terraform..."
  run_command "cd $SCRIPT_DIR/../terraform"
  run_command "terraform init"

  # Validate Terraform
  log_info "Validating Terraform..."
  run_command "terraform validate"

  # Run Terraform plan
  log_info "Running Terraform plan..."
  run_command "terraform plan -out=tfplan"

  # Prompt user to continue with a yes/no unless the first parameter is "confirm"
  if ! user_confirmed; then
    spacer
    if ! prompt_yes_no "Do you want to continue with the Terraform apply?"; then
      graceful_exit 0
    fi
  fi

  # Run Terraform apply
  log_info "Running Terraform apply..."
  run_command "terraform apply tfplan"

  # write the state to a file for debugging
  log_info "Writing Terraform state to file..."
  run_command "terraform show -json tfplan > tfplan_output.json"

  log_success "Terraform has finished setting up the k8s cluster."
fi

k8s_set_context_to_new_cluster

spacer
set_up_k8s_cluster

# Install Traefik and the demo apps
k8s_install_traefik
k8s_install_demo_apps

spacer
report_access_points
report_duration
k8s_set_up_dashboard_proxy
if [ "$cluster_type" == "k3s" ]; then
  spacer
  log_warn "Before you can access the cluster in this console, you need to run the following command:\n${BLUE}export KUBECONFIG=tmp/k3s.yaml${NC}"
fi
graceful_exit
