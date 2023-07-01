#!/bin/bash

# =================================================================================================
# This script uses Terraform, Helm, and kubectl to set up the EKS cluster and deploy the demo apps.
# =================================================================================================

set -e

# Import helper library
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "$SCRIPT_DIR/../lib/set_envs.sh"
source "$SCRIPT_DIR/../lib/helpers.sh"

trap trap_cleanup ERR

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
  echo -e "${YELLOW}Do you want to continue and apply the Terraform plan?${NC}"
  select yn in "Yes" "No"; do
    case $yn in
      Yes ) break;;
      No ) graceful_exit 0;;
    esac
  done
fi

# Run Terraform apply
log_info "Running Terraform apply..."
run_command "terraform apply tfplan"

# write the state to a file for debugging
log_info "Writing Terraform state to file..."
run_command "terraform show -json tfplan > tf_output.json"

log_success "Terraform apply complete!"

# update kubeconfig
log_info "Updating kubeconfig..."
run_command "aws eks --region $(terraform output -raw region) update-kubeconfig     --name $(terraform output -raw cluster_name)"

echo -e "
To destroy the infrastructure, run:
${BLUE}terraform destroy${NC}

To view resources created by this script on AWS, go to the link below and click ${YELLOW}Search resources${NC}:
${BLUE}https://${AWS_REGION}.console.aws.amazon.com/resource-groups/tag-editor/find-resources?region=${AWS_REGION}#query=regions:!%28${AWS_REGION}%29,resourceTypes:!%28%27AWS::AllSupported%27%29,tagFilters:!%28%28key:Project,values:!%28${TF_PROJECT}%29%29%29,type:TAG_EDITOR_1_0${NC}
"



# =================================================================================================
# Need to redo
# =================================================================================================
# if ! k8s_running; then
#   log_error "The EKS cluster does not appear to be running. Please ensure the cluster is fully set up and running and then run this script again."
#   graceful_exit 1
# fi

# if ! k8s_dashboard_installed && ! k8s_install_dashboard; then
#   log_error "Failed to install dashboard."
#   graceful_exit 1
# fi

# if ! k8s_admin_user_exists && ! k8s_create_admin_user; then
#   log_error "Failed to create admin user."
#   graceful_exit 1
# fi

# k8_generate_token_for_admin_user
# log_success "Dashboard installed and admin user created."
# k8s_start_proxy
# k8s_show_dashboard_access_instructions
