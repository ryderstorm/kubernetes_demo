#!/bin/bash

# =================================================================================================
# Bash Helpers
# this file contains helper functions and variables for the bash scrripts used in this project.
# =================================================================================================

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# =================================================================================================
# Bash Colors and Spacers
# Sets variables that can be used to create colors in text
# or add spacers to improve readability.
# Must use `echo -e` for for these to work.
#
# Example usage:
# echo -e "${SPACER}${BLUE}This is blue.${YELLOW}And this is yellow.${NC}And this is the defaul color."
# =================================================================================================

export BLACK='\033[0;30m'
export WHITE='\033[1;37m'

export RED='\033[0;31m'
export ORANGE='\033[0;33m'
export YELLOW='\033[1;33m'
export GREEN='\033[0;32m'
export BLUE='\033[0;34m'
export CYAN='\033[0;36m'
export PURPLE='\033[0;35m'

export LIGHTRED='\033[1;31m'
export LIGHTGREEN='\033[1;32m'
export LIGHTBLUE='\033[1;34m'
export LIGHTCYAN='\033[1;36m'
export LIGHTPURPLE='\033[1;35m'

export LIGHTGRAY='\033[0;37m'
export DARKGRAY='\033[1;30m'

# Resets text back to default color for shell.
# Should always be added to the end of any color strings to ensure
# that text color is reset back to normal.
export NC='\033[0m'

# Spacer
export SPACER="\n====================================================\n"

# =================================================================================================
# Functions for Output Formatting and Logging
# =================================================================================================

spacer() {
  echo -e "${WHITE}${SPACER}${NC}"
}

log_success() {
  echo -e "${GREEN}[SUCCESS]${NC} " "$@"
}

log_info() {
  echo -e "${WHITE}[INFO]${NC}    " "$@"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC}    " "$@"
}

log_error() {
  echo -e "${RED}[ERROR]${NC}   " "$@"
}

# =================================================================================================
# Helper Functions
# =================================================================================================

# Function to use in trap to handle errors and gracefully exit the script
trap_cleanup() {
  spacer
  if [ -n "$SCRIPT_DIR" ]; then
    cd "$SCRIPT_DIR/../" || true
  fi
  log_error "Exiting because the script encountered an error or was interrupted."
  graceful_exit
}

# Function for running a command and reporting success or failure
# Also shows the command that is being run to aid in debugging
run_command() {
  command=$1
  override_exit_on_error=$2
  if [ -z "$command" ]; then
    echo -e "${RED}No command provided.${NC}"
    exit 1
  fi
  echo -e "${BLUE}$command${NC}\n"

  if eval "$command"; then
    return 0
  else
    if [ "$override_exit_on_error" = true ]; then
      return 1
    fi
    if [ "$EXIT_ON_ERROR" = true ]; then
      graceful_exit 1
    fi
    return 1
  fi
}

# Function for prompting user to confirm the supplied question/action
prompt_yes_no() {
  question=$1
  if [ -z "$question" ]; then
    echo -e "\n${RED}You must supply a question to the prompt_yes_no function.${NC}"
    false; return
  fi
  echo -e "${YELLOW}$question${NC}"
  select yn in "Yes" "No"; do
    case $yn in
      Yes ) return 0;;
      No ) return 1;;
    esac
  done
}

# Function for gracefully exiting the script
graceful_exit() {
  # if no exit code is provided, default to 0
  exit_code=${1:-0}
  spacer
  echo -e "${YELLOW}Exiting...${NC}"
  exit "$exit_code"
}

# =================================================================================================
# Kubernetes Helper Functions
# =================================================================================================

k8s_running() {
  kubectl get nodes &>/dev/null && return 0 || return 1
}

# Function for checking if the k8s dashboard is installed
k8s_dashboard_installed() {
  kubectl get ns kubernetes-dashboard  &>/dev/null && return 0 || return 1
}

k8s_admin_user_exists() {
  kubectl get sa admin-user -n kubernetes-dashboard && return 0 || return 1
}

# Kubectl command for installing the latest version of the Kubernetes dashboard
k8s_install_dashboard() {
  log_info "Installing KubernetesDashboard in..."
  # from: https://docs.k3s.io/installation/kube-dashboard#deploying-the-kubernetes-dashboard
  github_url=https://github.com/kubernetes/dashboard/releases
  version_kube_dashboard=$(curl -w '%{url_effective}' -I -L -s -S ${github_url}/latest -o /dev/null | sed -e 's|.*/||')
  command="kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/${version_kube_dashboard}/aio/deploy/recommended.yaml"
  run_command "$command"
  if ! k8s_wait_for_pod "kubernetes-dashboard" "k8s-app=kubernetes-dashboard"; then
    log_error "Failed to install the Kubernetes dashboard"
    return 1
  fi
  log_success "Successfully installed the Kubernetes dashboard"
}

k8s_create_admin_user() {
  log_info "Creating k8s admin-user..."
  # from: https://docs.k3s.io/installation/kube-dashboard#dashboard-rbac-configuration
  command="kubectl apply -f $SCRIPT_DIR/../kubernetes/deployments/dashboard/dashboard.admin-user.yaml -f $SCRIPT_DIR/../kubernetes/deployments/dashboard/dashboard.admin-user-role.yaml"
  if ! run_command "$command"; then
    log_error "Failed to create user in k3s: admin-user"
    return 1
  fi
}

k8s_generate_token_for_admin_user() {
  spacer
  log_info "Generating token for k8s admin-user..."
  command="kubectl -n kubernetes-dashboard create token admin-user"
  token=$(eval "$command")
  if [ $? -eq 0 ]; then
    echo "$token" | xclip -selection clipboard
    log_success "Token created!"
    echo -e "Token for admin-user:${BLUE}\n$token${NC}"
    echo -e "The token has been copied to your clipboard."
  else
    log_error "Failed to create token for k8s admin-user."
    return 1
  fi
}

k8s_start_proxy() {
  spacer
  # find any existing processes that are listening on port 8001 and kill them
  log_info "Stopping any existing proxy for k3s..."
  sudo kill "$(sudo lsof -t -i:8001)" || true

  log_info "Starting proxy for k3s..."
  kubectl proxy &>/dev/null & disown
  log_success "Proxy for k3s is running."
}

k8s_show_dashboard_access_instructions() {
  spacer
  echo -e "To access the Kubernetes dashboard, go to the URL below in your browser and enter the token when prompted.\n\n${BLUE}\http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/#/workloads?namespace=_all${NC}"

}

k8s_wait_for_pod() {
  local namespace="$1"
  local labels="$2"

  if [ -z "$namespace" ] || [ -z "$labels" ]; then
    log_error "You must provide a namespace and labels to the k8s_wait_for_pod function."
    return 1
  fi
  command="kubectl get pods -n '$namespace' -l '$labels' -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null"
  log_info "Waiting for pod with labels [$labels] to be ready with command:\n${BLUE}$command${NC}"
  printf '...'
  TIMEOUT=60
  START_TIME=$(date +%s)
  while true; do
    CURRENT_TIME=$(date +%s)
    ELAPSED_TIME=$((CURRENT_TIME - START_TIME))
    if [[ $ELAPSED_TIME -gt $TIMEOUT ]]; then
      log_error "Timed out after waiting $TIMEOUT seconds for pod with labels [$labels] to be ready."
      return 1
    fi
    status=$(eval "$command")
    if [ "$status" == "true" ]; then
      echo -e "\n"
      log_success "Pod with labels [$labels] is ready!"
      return 0
    fi
    printf "."
    sleep 1
  done
  echo -e "\n"
  log_error "Timed out after waiting $TIMEOUT seconds for pod with labels [$labels] to be ready."
  return 1
}

set_traefik_endpoint() {
  hostname=$(kubectl get svc traefik -n traefik -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
  ip=$(kubectl get svc traefik -n traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
  # if both the hostname and ip are empty, throw an error
  if [ -z "$hostname" ] && [ -z "$ip" ]; then return 1; fi
  # if the hostname is empty, use the IP
  if [ -z "$hostname" ]; then hostname=$ip; fi
  export TRAEFIK_ENDPOINT=$hostname
  return 0
}

traefik_endpoint_responding() {
  set_traefik_endpoint
  if curl -s -o /dev/null --fail "http://$TRAEFIK_ENDPOINT/dashboard/"; then
    return 0
  else
    return 1
  fi
}

wait_for_traefik_endpoint() {
  printf "Waiting for Traefik load balancer to be ready..."
  TIMEOUT=60
  START_TIME=$(date +%s)
  while true; do
    CURRENT_TIME=$(date +%s)
    ELAPSED_TIME=$((CURRENT_TIME - START_TIME))
    if [ $ELAPSED_TIME -gt $TIMEOUT ]; then
      spacer
      log_error "Timed out waiting for Traefik load balancer to be ready."
      graceful_exit 1
    fi
    if traefik_endpoint_responding; then
      echo ""
      return 0
    fi
    printf "."
    sleep 1
  done
}

display_app_urls() {
  echo -e "Displaying app URLs..."
  set_traefik_endpoint

  # show the traefik dashboard url
  echo -e "Traefik Dashboard URL:\n${BLUE}http://$TRAEFIK_ENDPOINT/dashboard/${NC}\n"
  # loop through each app in the demo-apps namespace and print the url
  echo -e "App URLs:"
  for app in $(kubectl get ingress -n demo-apps -o jsonpath='{.items[*].metadata.name}'); do
    path=$(kubectl get ingress "$app" -n demo-apps -o jsonpath='{.spec.rules[0].http.paths[0].path}')
    echo -e "${BLUE}http://$TRAEFIK_ENDPOINT$path${NC}"
  done
}
