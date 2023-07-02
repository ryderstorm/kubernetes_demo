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

log_success "Terraform has finished setting up the EKS cluster."

# update kubeconfig if the current context is not the new cluster
if [ "$(kubectl config current-context)" != "$(terraform output -raw cluster_name)" ]; then
  spacer
  log_info "Configuring kubectl to work with new EKS cluster..."
  run_command "kubectl config delete-context $(terraform output -raw cluster_name) &> /dev/null || true"
  run_command "aws eks --region $(terraform output -raw region) update-kubeconfig     --name $(terraform output -raw cluster_name)"
  run_command "kubectl config rename-context $(kubectl config current-context) $(terraform output -raw cluster_name)"
fi

spacer

set_up_k8s_cluster

# Install Traefik and the demo apps
k8s_install_traefik
k8s_install_demo_apps

spacer

log_success "Cluster apps are installed and ready to use."
log_info "You can access apps in the cluster at the following URLs:"
display_app_urls
graceful_exit

spacer
echo -e "
To destroy the infrastructure, run:
${BLUE}terraform destroy${NC}

To view resources created by this script on AWS, go to the link below and click ${YELLOW}Search resources${NC}:
${BLUE}https://${AWS_REGION}.console.aws.amazon.com/resource-groups/tag-editor/find-resources?region=${AWS_REGION}#query=regions:!%28${AWS_REGION}%29,resourceTypes:!%28%27AWS::AllSupported%27%29,tagFilters:!%28%28key:Project,values:!%28${TF_PROJECT}%29%29%29,type:TAG_EDITOR_1_0${NC}
"
