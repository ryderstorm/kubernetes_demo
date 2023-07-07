#!/bin/bash

# =================================================================================================
# This script runs a load test against the timestamp app.
# =================================================================================================

set -e

# Import helper libriaries
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "$SCRIPT_DIR/../lib/set_envs.sh"
source "$SCRIPT_DIR/../lib/helpers.sh"

trap trap_cleanup ERR SIGINT SIGTERM

# Check for required apps
declare -A REQUIRED_APPS=(
  ["curl"]="curl --version ||| https://curl.se/download.html"
  ["jq"]="jq --version ||| https://stedolan.github.io/jq/download/"
  ["kubectl"]="kubectl version --client ||| https://kubernetes.io/docs/tasks/tools/#kubectl"
)
export REQUIRED_APPS
check_installed_apps

# =================================================================================================
# Main Script
# =================================================================================================

host=$(kubectl get ingress -n demo-apps -l app=timestamp -o jsonpath='{.items[*].spec.rules[*].host}')
while true; do
  version=$(curl -s "$host/version" | jq -r '.version')
  message=$(curl -s "$host" | jq -r '.message')
  echo -e "$(date) | ${BLUE}$version${NC} | ${YELLOW}$message${NC}"
  sleep 0.25
done
