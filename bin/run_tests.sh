#!/bin/bash

# =================================================================================================
# This script runs the responsiveness test for the demo apps in the Kubernetes cluster.
# =================================================================================================

set -e

# Import helper library
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "$SCRIPT_DIR/../lib/set_envs.sh"
source "$SCRIPT_DIR/../lib/helpers.sh"
trap trap_cleanup ERR SIGINT SIGTERM

# Check for required apps
declare -A REQUIRED_APPS=(
  ["ruby"]="ruby --version ||| https://www.ruby-lang.org/en/documentation/installation/"
  ["kubectl"]="kubectl version --client ||| https://kubernetes.io/docs/tasks/tools/#kubectl"
)
export REQUIRED_APPS
check_installed_apps

# =================================================================================================
# Main Script
# =================================================================================================

prompt_for_cluster_type
spacer
k8s_set_context_to_new_cluster
traefik_set_endpoints

spacer
log_info "Setting up for responsiveness test..."
run_command "bundle install"

spacer
log_info "Running tests..."
rspec "$SCRIPT_DIR/../spec/responsiveness_spec.rb"
