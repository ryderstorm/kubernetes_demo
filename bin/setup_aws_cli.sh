#!/bin/bash

# =================================================================================================
# This script sets up the AWS CLI with a new user to keep demo resources isolated.
# The new user will have full access to EC2 for setting up the demo kubernetes cluster.
# =================================================================================================

set -e

# Import helper library
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "$SCRIPT_DIR/../lib/bash_helpers.sh"

# =================================================================================================
# Set Up
# =================================================================================================

# Define variables
IAM_USER_NAME="xyz-demo-user"
POLICY_NAME="xyz-demo-policy"
POLICY_DOCUMENT=$(jq -c . "$SCRIPT_DIR/../config/iam_policy.json")

# =================================================================================================
# Helper Functions
# =================================================================================================

create_user() {
  log_info "Creating IAM user: $IAM_USER_NAME"
  run_command "aws iam create-user --user-name '$IAM_USER_NAME'"
}

user_already_exists() {
  run_command "aws iam get-user --user-name '$IAM_USER_NAME' &> /dev/null" true
}

user_has_policy() {
  run_command "aws iam get-user-policy --user-name '$IAM_USER_NAME' --policy-name '$POLICY_NAME' &> /dev/null" true
}

user_has_access_keys() {
  run_command "aws iam list-access-keys --user-name '$IAM_USER_NAME' --query 'AccessKeyMetadata[*].AccessKeyId' --output json | jq -r '.[]' | grep -q ." true
}

delete_user() {
  if ! user_already_exists; then
    log_error "IAM user [$IAM_USER_NAME] does not exist."
    graceful_exit
  fi
  if prompt_yes_no "Are you sure you want to delete the IAM user [$IAM_USER_NAME]?"; then
    run_command "aws iam delete-user-policy --user-name '$IAM_USER_NAME' --policy-name '$POLICY_NAME'" true || true
    delete_user_access_keys
    remove_iam_user_credentials
    run_command "aws iam delete-user --user-name '$IAM_USER_NAME'"
    log_success "IAM user deleted!"
  fi
  graceful_exit
}

delete_user_access_keys() {
  log_info "Deleting access keys for IAM user [$IAM_USER_NAME]..."
  run_command "aws iam list-access-keys --user-name '$IAM_USER_NAME' --query 'AccessKeyMetadata[*].AccessKeyId' --output json | jq -r '.[]' | xargs -I {} aws iam delete-access-key --access-key-id {} --user-name '$IAM_USER_NAME'" true || true
}

remove_iam_user_credentials() {
  log_info "Removing IAM user credentials from ~/.aws/credentials..."
  sed -i "/\[$IAM_USER_NAME\]/,/^$/d" ~/.aws/credentials
}

# =================================================================================================
# Main Script
# =================================================================================================

# If the first parameter is "delete", delete the user and exit
if [[ "$1" == "delete" ]]; then
  delete_user
  graceful_exit
fi

log_info "Checking if user [$IAM_USER_NAME] already exists..."
if user_already_exists; then
  log_info "IAM user already exists."
else
  create_user
fi

log_info "Checking if policy is already attached to IAM user..."
if user_has_policy; then
  log_info "The [$POLICY_NAME] policy is already attached to the user."
else
  log_info "Attaching policy to IAM user..."
  run_command "aws iam put-user-policy --user-name '$IAM_USER_NAME' --policy-name '$POLICY_NAME' --policy-document '$POLICY_DOCUMENT'"
  # run_command "aws iam put-user-policy --user-name '$IAM_USER_NAME' --policy-name '$POLICY_NAME' --cli-input-json '$POLICY_DOCUMENT'"
fi

log_info "Checking if user already has access keys..."
if user_has_access_keys; then
  log_info "IAM user already has access keys."
else
  log_info "Creating credentials for IAM user..."
  # run_command "aws iam create-access-key --user-name '$IAM_USER_NAME' --query 'AccessKey.[AccessKeyId,SecretAccessKey]' --output text > tmp/iam_user_keys.txt"
  run_command "aws iam create-access-key --user-name '$IAM_USER_NAME' > tmp/iam_user_keys.txt"
fi

# check if credentials file already has a profile for the IAM user
log_info "Updating credentials file with new profile for IAM user..."
# update the credentials file with the new new access key id and secret access key
ACCESS_KEY_ID=$(cat tmp/iam_user_keys.txt | jq -r '.AccessKey.AccessKeyId')
SECRET_ACCESS_KEY=$(cat tmp/iam_user_keys.txt | jq -r '.AccessKey.SecretAccessKey')
run_command "aws configure set aws_access_key_id '$ACCESS_KEY_ID' --profile '$IAM_USER_NAME'"
run_command "aws configure set aws_secret_access_key '$SECRET_ACCESS_KEY' --profile '$IAM_USER_NAME'"
run_command "aws configure set region '$AWS_REGION' --profile '$IAM_USER_NAME'"

# switch to the new profile
export AWS_PROFILE="$IAM_USER_NAME"

# test the new profile
log_info "Testing the new profile by listing EC2 instances, please wait..."

# wait for the new profile to be ready by repeatedly trying to list EC2 instances until it succeeds
TIMEOUT=60
START_TIME=$(date +%s)
while true; do
  if run_command "aws ec2 describe-instances &> /dev/null" true; then
    log_success "Success! The new profile is ready to use."
    log_info "You can switch to the new profile by running the following command:"
    log_info "${BLUE}export AWS_PROFILE=$IAM_USER_NAME${NC}"
    graceful_exit
  fi
  CURRENT_TIME=$(date +%s)
  ELAPSED_TIME=$((CURRENT_TIME - START_TIME))
  if [[ $ELAPSED_TIME -gt $TIMEOUT ]]; then
    log_error "Timed out after waiting $TIMEOUT seconds for the new profile to be ready."
    graceful_exit 1
  fi
  sleep 1
done
