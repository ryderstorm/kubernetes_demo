#!/bin/bash

# =================================================================================================
# This script sets up an AWS ECR repository for the demo application.
# =================================================================================================

set -e

# Import helper library
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "$SCRIPT_DIR/../lib/set_envs.sh"
source "$SCRIPT_DIR/../lib/helpers.sh"
trap trap_cleanup ERR SIGINT SIGTERM


# =================================================================================================
# Helper Functions
#
# NOTE: You can only create public repos in us-east-1. That is why we hardcode the region here.
# =================================================================================================

aws_ecr_repo_exists() {
  aws ecr describe-repositories --region us-east-1 --repository-names "$ECR_REPO_NAME" &> /dev/null || return 1
}

aws_ecr_repo_create() {
  log_info "Creating ECR repository: $ECR_REPO_NAME"
  run_command "aws ecr create-repository --region us-east-1 --repository-name '$ECR_REPO_NAME'"
}

aws_ecr_repo_set_url() {
  url=$(aws ecr describe-repositories --region us-east-1 --repository-names "$ECR_REPO_NAME" | jq -r '.repositories[0].repositoryUri')
  export ECR_REPO_URI="$url"
  log_info "Set AWS ECR URI to: ${BLUE}$ECR_REPO_URI${NC}"
}

aws_ecr_repo_delete() {
  log_info "Deleting ECR repository: $ECR_REPO_NAME"
  run_command "aws ecr delete-repository --region us-east-1 --repository-name '$ECR_REPO_NAME' --force"
}

aws_ecr_policy_content() {
  jq -c . "$SCRIPT_DIR/../config/ecr_policy.json"
}

aws_ecr_set_policy() {
  log_info "Creating ECR policy: $ECR_POLICY_NAME"
  run_command "aws ecr set-repository-policy --region us-east-1 --repository-name '$ECR_REPO_NAME' --policy-text '$(aws_ecr_policy_content)'"
}

aws_ecr_authenticate() {
  log_info "Authenticating with AWS ECR..."
  run_command "aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_REPO_URI"
}

aws_ecr_list_repositories() {
  aws ecr describe-repositories --region us-east-1 | jq -r '.repositories[].repositoryName'
}

# =================================================================================================
# Main Script
# =================================================================================================

if [ "$1" == "delete" ]; then
  aws_ecr_repo_delete
  log_success "ECR repository deleted: $ECR_REPO_NAME"
  graceful_exit
fi

if [ "$1" == "set_repo_url" ]; then
  aws_ecr_repo_set_url
  silent_exit
fi

if aws_ecr_repo_exists; then
  log_info "ECR repository already exists: $ECR_REPO_NAME"
  aws_ecr_repo_set_url
  aws_ecr_authenticate
else
  aws_ecr_repo_create
  aws_ecr_repo_set_url
  aws_ecr_authenticate
  aws_ecr_set_policy
fi

log_success "ECR repository is ready to use: $ECR_REPO_NAME"
log_info "Use this URI to push/pull images: ${BLUE}$ECR_REPO_URI${NC}"
graceful_exit
