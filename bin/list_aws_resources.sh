#!/bin/bash

set -e
# load the bash helpers
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "$SCRIPT_DIR/../lib/set_envs.sh"
source "$SCRIPT_DIR/../lib/helpers.sh"

# This script lists all resources associatd with the account.
# You can keep it running in the background for a constant view of resources
# by passing the "watch" parameter, e.g.:
#   bin/list_aws_resources.sh watch

list_resources() {
  current_dir=$(pwd)
  cd "$SCRIPT_DIR/../terraform"
  terraform_count=$(terraform state list | wc -l)
  cd "$current_dir"
  output="${YELLOW}$(date)${NC}\n\n"
  output+="${WHITE}Found ${YELLOW}${terraform_count}${WHITE} resources via ${MAGENTA}terraform${NC}\n\n"
  aws_user=$(aws sts get-caller-identity --query 'Arn' --output text | cut -d '/' -f 2)
  output+="${WHITE}Current AWS CLI user: ${GREEN}$aws_user${NC}\n"
  resources=$(aws resourcegroupstaggingapi get-resources --region "$AWS_REGION" --resources-per-page 100 | jq -r '.ResourceTagMappingList[].ResourceARN')
  resource_count=$(echo "$resources" | wc -l)
  resource_list=$(echo "$resources"  | cut -d ':' -f6 | cut -d '/' -f1 | sort | uniq -c | sed 's/^[[:space:]]*//')
  output+="${WHITE}Found ${YELLOW}${resource_count}${WHITE} resources via ${MAGENTA}aws cli${WHITE}:\n${BLUE}${resource_list}${NC}"
  if [[ "$WATCH" == "1" ]]; then
    clear
  fi
  echo -e "$output"
}

# if first paramater is "watch", run the script in a loop
if [[ "$1" == "watch" ]]; then
  while true; do
    export WATCH=1
    list_resources
    sleep 5
  done
else
  list_resources
fi
