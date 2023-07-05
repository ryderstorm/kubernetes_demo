#!/bin/bash

# =================================================================================================
# This script uses Terraform, Helm, and kubectl to set up the EKS cluster and deploy the demo apps.
# =================================================================================================

set -e

# Import helper library
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "$SCRIPT_DIR/../lib/set_envs.sh"
source "$SCRIPT_DIR/../lib/helpers.sh"

trap trap_cleanup ERR SIGINT SIGTERM

declare -A REQUIRED_APPS=(
  ["awscli"]="aws --version ||| https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html#getting-started-install-instructions"
  ["helm"]="helm version --client ||| https://helm.sh/docs/intro/install/"
  ["jq"]="jq --version ||| https://stedolan.github.io/jq/download/"
  ["kubectl"]="kubectl version --client ||| https://kubernetes.io/docs/tasks/tools/#kubectl"
  ["terraform"]="terraform version ||| https://learn.hashicorp.com/tutorials/terraform/install-cli"
)
export REQUIRED_APPS
check_installed_apps

spacer
# Initialize Terraform
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
if [ "$1" != "confirm" ]; then
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

log_success "Terraform has finished setting up the EKS cluster."

k8s_clear_stale_kubectl_data
k8s_set_context_to_aws_eks

spacer

set_up_k8s_cluster

# Install Traefik and the demo apps
k8s_install_traefik
k8s_install_demo_apps

spacer

log_success "Cluster apps are installed and ready to use."
log_info "You can access apps in the cluster at the following URLs:"
report_access_points

k8s_set_up_dashboard_proxy
graceful_exit
