#!/bin/bash

# =================================================================================================
# This script uses Terraform to destroy the EKS cluster and all associated resources.
# =================================================================================================

set -e

# Import helper library
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "$SCRIPT_DIR/../lib/set_envs.sh"
source "$SCRIPT_DIR/../lib/helpers.sh"

trap trap_cleanup ERR SIGINT SIGTERM

# Prompt user to continue with a yes/no unless the first parameter is "confirm"
if [ "$1" != "confirm" ]; then
  spacer
  log_info "This script will destroy the EKS cluster and all associated resources."
  if ! prompt_yes_no "Do you want to continue with the Terraform destroy?"; then
    graceful_exit 0
  fi
fi
spacer
log_info "Running Terraform Destroy..."
run_command "cd $SCRIPT_DIR/../terraform"
run_command "terraform destroy -auto-approve"

graceful_exit
