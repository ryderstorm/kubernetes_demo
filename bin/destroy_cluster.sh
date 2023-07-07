#!/bin/bash

# =================================================================================================
# This script uses Terraform to destroy the k8s cluster and all associated resources.
# =================================================================================================

set -e

# Start timer
SCRIPT_START=$(date +%s)

# Import helper library
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "$SCRIPT_DIR/../lib/set_envs.sh"
source "$SCRIPT_DIR/../lib/helpers.sh"

trap trap_cleanup ERR SIGINT SIGTERM

# Check for required apps
declare -A REQUIRED_APPS=(
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
if [ "$CLUSTER_TYPE" == "k3s" ]; then
  log_info "Uninstalling k3s..."
  run_command "/usr/local/bin/k3s-uninstall.sh"
else
  log_warn "This script will use Terraform to destroy all managed resources."
  if ! prompt_yes_no "Do you want to continue with the Terraform destroy?"; then
    graceful_exit 0
  fi
  spacer
  log_info "Running Terraform Destroy..."
  run_command "cd $SCRIPT_DIR/../terraform"
  run_command "terraform destroy -auto-approve"
fi
report_duration
graceful_exit
