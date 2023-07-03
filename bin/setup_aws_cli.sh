#!/bin/bash

# =================================================================================================
# This script sets up the AWS CLI with a new user to keep demo resources isolated.
# The new user will have full access to EC2 for setting up the demo kubernetes cluster.
# =================================================================================================

set -e

# Import helper library
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "$SCRIPT_DIR/../lib/set_envs.sh"
source "$SCRIPT_DIR/../lib/helpers.sh"
trap trap_cleanup ERR SIGINT SIGTERM

# =================================================================================================
# Helper Functions
# =================================================================================================

create_user() {
  if user_already_exists; then return; fi
  log_info "Creating IAM user: $IAM_USER_NAME"
  run_command "aws iam create-user --user-name '$IAM_USER_NAME'"
}

user_already_exists() {
  run_command "aws iam get-user --user-name '$IAM_USER_NAME' &> /dev/null" true
}

iam_policy_content() {
  jq -c . "$SCRIPT_DIR/../config/iam_policy.json"
}

user_has_policy() {
  run_command "aws iam get-user-policy --user-name '$IAM_USER_NAME' --policy-name '$POLICY_NAME' &> /dev/null" true
}

user_has_access_keys() {
  run_command "aws iam list-access-keys --user-name '$IAM_USER_NAME' --query 'AccessKeyMetadata[*].AccessKeyId' --output json | jq -r '.[]' | grep -q ." true
}

user_has_login_profile() {
  run_command "aws iam get-login-profile --user-name '$IAM_USER_NAME' &> /dev/null" true
}

update_user_policy() {
  if user_has_policy; then delete_user_policies; fi
  log_info "Updating policies attached to IAM user..."
  run_command "aws iam put-user-policy --user-name '$IAM_USER_NAME' --policy-name '$POLICY_NAME' --policy-document '$(iam_policy_content)'"
}

update_access_credentials() {
  if user_has_access_keys; then delete_user_access_keys; fi
  log_info "Updating access credentials for IAM user..."
  run_command "aws iam create-access-key --user-name '$IAM_USER_NAME' > tmp/iam_user_keys.txt"
  ACCESS_KEY_ID=$(cat tmp/iam_user_keys.txt | jq -r '.AccessKey.AccessKeyId')
  SECRET_ACCESS_KEY=$(cat tmp/iam_user_keys.txt | jq -r '.AccessKey.SecretAccessKey')
  run_command "aws configure set aws_access_key_id '$ACCESS_KEY_ID' --profile '$IAM_USER_NAME'"
  run_command "aws configure set aws_secret_access_key '$SECRET_ACCESS_KEY' --profile '$IAM_USER_NAME'"
  run_command "aws configure set region '$AWS_REGION' --profile '$IAM_USER_NAME'"
}

generate_login_credentials() {
  if user_has_login_profile; then delete_login_profile; fi
  log_info "Generating login credentials for AWS Console..."
  user_password=$(openssl rand -base64 32)
  echo "$user_password" > "$SCRIPT_DIR/../tmp/aws_console_password.txt"
  run_command "aws iam create-login-profile --user-name '$IAM_USER_NAME' --password '$user_password'"
}

delete_user() {
  if ! user_already_exists; then
    log_error "IAM user [$IAM_USER_NAME] does not exist."
    graceful_exit
  fi
  if prompt_yes_no "Are you sure you want to delete the IAM user [$IAM_USER_NAME]?"; then
    delete_user_policies
    delete_user_access_keys
    delete_login_profile
    remove_iam_user_credentials
    run_command "aws iam delete-user --user-name '$IAM_USER_NAME'"
    log_success "IAM user deleted!"
  fi
  graceful_exit
}

delete_user_policies() {
  log_info "Deleting policies for IAM user [$IAM_USER_NAME]..."
  run_command "aws iam list-user-policies --user-name '$IAM_USER_NAME' --query 'PolicyNames[*]' --output json | jq -r '.[]' | xargs -I {} aws iam delete-user-policy --user-name '$IAM_USER_NAME' --policy-name {}" true || true
}

delete_user_access_keys() {
  log_info "Deleting access keys for IAM user [$IAM_USER_NAME]..."
  run_command "aws iam list-access-keys --user-name '$IAM_USER_NAME' --query 'AccessKeyMetadata[*].AccessKeyId' --output json | jq -r '.[]' | xargs -I {} aws iam delete-access-key --access-key-id {} --user-name '$IAM_USER_NAME'" true || true
}

delete_login_profile() {
  log_info "Deleting login profile for IAM user [$IAM_USER_NAME]..."
  run_command "aws iam delete-login-profile --user-name '$IAM_USER_NAME'" true || true
}

remove_iam_user_credentials() {
  log_info "Removing IAM user credentials from ~/.aws/credentials..."
  sed -i "/\[$IAM_USER_NAME\]/,/^$/d" ~/.aws/credentials
}

show_success_for_aws_cli_setup() {
  spacer
  log_success "Success! The new profile is ready to use."
  echo -e "

You can switch this console window to the new profile by running the following command:
${GREEN}export AWS_PROFILE=$IAM_USER_NAME${NC}

To login to the AWS Console with this account, go to:
${BLUE}https://${AWS_REGION}.console.aws.amazon.com/${NC}

and use the following credentials:
${BLUE}Account ID:${NC} $(aws sts get-caller-identity --query 'Account' --output text)
${BLUE}Username:${NC} $IAM_USER_NAME
${BLUE}Password:${NC} $(cat "$SCRIPT_DIR/../tmp/aws_console_password.txt")
"

  graceful_exit
}

# =================================================================================================
# Main Script
# =================================================================================================

# If the first parameter is "delete", delete the user and exit
if [[ "$1" == "delete" ]]; then
  delete_user
  graceful_exit
fi

create_user
update_user_policy
update_access_credentials
generate_login_credentials
export AWS_PROFILE="$IAM_USER_NAME"
log_info "Testing the new profile by listing EC2 instances, please wait..."
TIMEOUT=60
START_TIME=$(date +%s)
while true; do
  CURRENT_TIME=$(date +%s)
  ELAPSED_TIME=$((CURRENT_TIME - START_TIME))
  if [[ $ELAPSED_TIME -gt $TIMEOUT ]]; then
    log_error "Timed out after waiting $TIMEOUT seconds for the new profile to be ready."
    graceful_exit 1
  fi
  if run_command "aws ec2 describe-instances &> /dev/null" true; then
    show_success_for_aws_cli_setup
  fi
  sleep 1
done
