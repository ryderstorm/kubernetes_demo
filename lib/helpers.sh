#!/bin/bash

# =================================================================================================
# Bash Helpers
# this file contains helper functions and variables for the bash scrripts used in this project.
# =================================================================================================

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export ROOT_DIR="$SCRIPT_DIR/.."

set -e

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

terraform_dir() {
  echo "$ROOT_DIR/terraform"
}

# =================================================================================================
# Kubernetes Helper Functions
# =================================================================================================

k8s_running() {
  kubectl get nodes &>/dev/null && return 0 || return 1
}

k8s_set_context_to_aws_eks() {
  unset KUBECONFIG
  cluster_name=$(terraform -chdir="$(terraform_dir)" output -raw cluster_name)
  if [ "$(kubectl config current-context 2>/dev/null)" != "$cluster_name" ]; then
    spacer
    log_info "Configuring kubectl to work with the EKS cluster..."
    run_command "kubectl config delete-context $cluster_name &> /dev/null || true"
    run_command "aws eks --region $AWS_REGION update-kubeconfig --name $cluster_name"
    run_command "kubectl config rename-context $(kubectl config current-context) $cluster_name"
  fi
}

k8s_dashboard_installed() {
  kubectl get ns kubernetes-dashboard  &>/dev/null && return 0 || return 1
}

k8s_admin_user_exists() {
  kubectl get sa admin-user -n kubernetes-dashboard && return 0 || return 1
}

set_docker_hub_secret() {
  namespace=$1
  if kubectl get secret docker-hub-creds -n "$namespace" &>/dev/null; then
    log_info "Clearing existing docker hub secret for namespace: ${BLUE}$namespace${NC}"
    run_command "kubectl delete secret docker-hub-creds -n '$namespace'"
  fi
  log_info "Setting docker hub secret for namespace: ${BLUE}$namespace${NC}"
  if ! kubectl get namespace "$namespace" &>/dev/null; then
    run_command "kubectl create namespace $namespace"
  fi
  run_command "kubectl create secret generic docker-hub-creds --from-file=.dockerconfigjson='$HOME/.docker/config.json' --type=kubernetes.io/dockerconfigjson -n '$namespace'"
  log_success "Docker hub secret set for namespace: ${BLUE}$namespace${NC}"
}

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

set_up_k8s_cluster() {
  if ! k8s_running; then
    log_error "k3s is not running. Please ensure k3s is installed and running and then run this script again."
    graceful_exit 1
  fi

  if ! k8s_dashboard_installed && ! k8s_install_dashboard; then
    log_error "Failed to install dashboard."
    graceful_exit 1
  fi

  if ! k8s_admin_user_exists && ! k8s_create_admin_user; then
    log_error "Failed to create admin user."
    graceful_exit 1
  fi

  k8s_generate_token_for_admin_user
  log_success "Dashboard installed and admin user created."
  k8s_start_proxy
  k8s_show_dashboard_access_instructions
}

k8s_install_traefik() {
  log_info "Installing Traefik..."
  set_docker_hub_secret "traefik"
  run_command "helm repo add traefik https://helm.traefik.io/traefik"
  run_command "helm repo update"
  values_file="$SCRIPT_DIR/../kubernetes/helm/values/traefik/traefik-values.yaml"
  command="helm upgrade --install --create-namespace --values=$values_file -n traefik traefik traefik/traefik"
  run_command "$command"
  if ! k8s_wait_for_pod "traefik" "app.kubernetes.io/name=traefik" && ! traefik_wait_for_endpoint; then
    log_error "Failed to install Traefik."
    graceful_exit 1
  fi
  dashboard_file="$SCRIPT_DIR/../kubernetes/deployments/traefik/traefik-dashboard.yaml"
  command="cat '$dashboard_file' | sed 's/KUBERNETES_HOSTNAME/Host(\`traefik.$(traefik_endpoint_hostname)\`)/g' | kubectl apply -f -"
  run_command "$command"
  log_success "Successfully installed Traefik. Please try running this script again."
}

k8s_install_demo_apps() {
  set_docker_hub_secret "demo-apps"
  traefik_set_endpoint
  chart_folder="$SCRIPT_DIR/../kubernetes/helm/demo_app"
  values_folder="$SCRIPT_DIR/../kubernetes/helm/values/demo_apps"
  for values_file in "$values_folder"/*; do
    app=$(basename "$values_file" | sed 's/-values.yaml//g')
    log_info "Installing demo app: ${BLUE}$app${NC}"
    command="helm upgrade --install --create-namespace --values=$values_file --set ingress.host=$(traefik_endpoint_hostname) -n demo-apps $app $chart_folder"
    run_command "$command"
  done

  if ! k8s_wait_for_pod "demo-apps" "app=timestamp"; then
    log_error "Failed to install demo apps. Please try running this script again."
    graceful_exit 1
  fi
  log_success "Successfully installed demo apps."

}
# =================================================================================================
# Traefik Helper Functions
# =================================================================================================

traefik_endpoint_hostname() {
  if [ "$RUNNING_K3S" == "true" ]; then
    echo "$K3S_HOST_NAME"
    return 0
  fi
  kubectl get svc traefik -n traefik -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
}

traefik_endpoint_ip() {
  kubectl get svc traefik -n traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
}

traefik_set_endpoint() {
  hostname=$(traefik_endpoint_hostname)
  ip=$(traefik_endpoint_ip)
  # if both the hostname and ip are empty, throw an error
  if [ -z "$hostname" ] && [ -z "$ip" ]; then return 1; fi
  export TRAEFIK_ENDPOINT=$hostname
  return 0
}

traefik_dashboard_responding() {
  if curl -s -o /dev/null --fail "http://$(traefik_endpoint_ip)/dashboard/"; then
    return 0
  else
    return 1
  fi
}

traefik_wait_for_endpoint() {
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
    if traefik_dashboard_responding; then
      echo ""
      return 0
    fi
    printf "."
    sleep 1
  done
}

traefik_report_access_points() {
  traefik_set_endpoint
  ip=$(traefik_endpoint_ip)
  log_info "Reporting access points for Traefik and demo apps:"
  log_info "Traefik Dashboard URL:"
  log_info "${BLUE}http://traefik.$TRAEFIK_ENDPOINT/${NC}\n"
  log_info "App URLs:"
  for app in $(kubectl get ingress -n demo-apps -o jsonpath='{.items[*].metadata.name}'); do
    log_info "${BLUE}http://$app.$TRAEFIK_ENDPOINT${NC}"
  done

  if [ ! "$RUNNING_K3S" = true ]; then return 0; fi
  spacer
  log_info "To access the Traefik dashboard and demo apps you'll need to add the following entries to your /etc/hosts file:"
  echo -e "${BLUE}$ip $TRAEFIK_ENDPOINT${NC}"
  echo -e "${BLUE}$ip traefik.$TRAEFIK_ENDPOINT${NC}"
  for app in $(kubectl get ingress -n demo-apps -o jsonpath='{.items[*].metadata.name}'); do
    echo -e "${BLUE}$ip $app.$TRAEFIK_ENDPOINT${NC}"
  done
}
