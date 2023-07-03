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

# =================================================================================================
# Main Script
# =================================================================================================

# prompt the user for if they are running a local cluster or an EKS cluster
spacer
cluster_type=""
echo -e "${YELLOW}Are you running a local cluster or an EKS cluster?${NC}"
select yn in "Local" "EKS"; do
  case $yn in
    Local ) cluster_type="local"; break;;
    EKS ) cluster_type="eks"; break;;
  esac
done

if [ "$cluster_type" == "eks" ]; then
  k8s_set_context_to_aws_eks
else
  export KUBECONFIG="tmp/k3s.yaml"
  export RUNNING_K3S=true
fi

spacer
traefik_set_endpoint
if [ -z "$TRAEFIK_ENDPOINT" ]; then
  log_error "Could not determine the cluster endpoint. Is the cluster running?"
  graceful_exit 1
fi

log_info "Setting up for responsiveness test..."
run_command "bundle install"

spacer
CLUSTER_ENDPOINT="$TRAEFIK_ENDPOINT" rspec "$SCRIPT_DIR/../spec/responsiveness_spec.rb"
