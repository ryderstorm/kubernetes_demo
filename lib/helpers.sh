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
# General Helper Functions
# =================================================================================================

# Function to use in trap to handle errors and gracefully exit the script
trap_cleanup() {
  spacer
  if [ -n "$SCRIPT_DIR" ]; then
    cd "$SCRIPT_DIR/../" || true
  fi
  report_duration || true
  log_error "Exiting because the script encountered an error or was interrupted."
  graceful_exit
}

# Function to check if the user pre-confirmed the script
user_confirmed() {
  if [ "$USER_CONFIRMED" = true ]; then
    return 0
  else
    return 1
  fi
}

# Function to report script duration
report_duration() {
  spacer
  SCRIPT_STOP=$(date +%s)
  SCRIPT_TIME=$((SCRIPT_STOP - SCRIPT_START))
  SCRIPT_MINUTES=$((SCRIPT_TIME / 60))
  SCRIPT_SECONDS=$((SCRIPT_TIME % 60))
  log_info "Total time to run script: ${BLUE}$SCRIPT_MINUTES minutes, $SCRIPT_SECONDS seconds${NC}"
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
  report_duration || true
  echo -e "${YELLOW}Exiting...${NC}"
  exit "$exit_code"
}

terraform_dir() {
  echo "$ROOT_DIR/terraform"
}

current_commit_sha() {
  git rev-parse --short HEAD
}

prompt_for_cluster_type() {
  spacer
  echo -e "${WHITE}What type of k8s cluster are you working with?${NC}"
  select cluster_type in "AWS" "DigitalOcean" "k3s (local)" "Quit"; do
    case $cluster_type in
      AWS ) cluster_type=aws; break;;
      DigitalOcean ) cluster_type=digital-ocean; break;;
      "k3s (local)" ) cluster_type=k3s; break;;
      Quit ) graceful_exit 0;;
    esac
  done
  export CLUSTER_TYPE=$cluster_type
  export TF_VAR_cluster_type=$cluster_type
  export LOCAL_HOSTNAME="k8s-cluster-$CLUSTER_TYPE.local"
}

# =================================================================================================
# Checking for Dependencies
# =================================================================================================

# Returns a string of all the required app names in alphabetical order
required_app_names() {
  echo "${!REQUIRED_APPS[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '
}

# Reports the installation status of all required apps
check_installed_apps() {
  all_apps_installed=true
  installed_apps=()
  missing_apps=()
  log_info "Checking for required apps..."
  for app in $(required_app_names); do
    check_installed_command="${REQUIRED_APPS[$app]%%|||*} &> /dev/null"
    install_instructions="${REQUIRED_APPS[$app]##*|||}"
    if ! eval "$check_installed_command"; then
      missing_apps+=("${YELLOW}$app${NC} is not installed. See installation instructions here: ${BLUE}$install_instructions${NC}")
      all_apps_installed=false
    else
      installed_apps+=("$app")
    fi
  done
  for app in "${installed_apps[@]}"; do
    log_info "App is installed: ${GREEN}$app${NC}"
  done
  for app_install_instructions in "${missing_apps[@]}"; do
    log_error "$app_install_instructions"
  done
  if [ "$all_apps_installed" = false ]; then
    spacer
    log_error "Some apps are not installed. Please install them and try again."
    graceful_exit 1
  else
    log_success "All required apps are installed!"
  fi
}

# =================================================================================================
# k3s Helper Functions
# =================================================================================================


k3s_installed() {
  k3s --version &>/dev/null && return 0 || return 1
}

install_k3s() {
  spacer
  log_info "${WHITE}This script will install k3s onto your local machine.${NC}"
  log_warn "${WHITE}You will be prompted for your sudo password during the installation process.${NC}"
  if ! user_confirmed && ! prompt_yes_no "Do you wish to continue?"; then
    graceful_exit 0
  fi

  log_info "Installing k3s..."
  # from: https://rancher.com/docs/k3s/latest/en/installation/install-options/
  # the --write-kubeconfig-mode 644 flag allows k3s to be run as a non-root user
  run_command "curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC='--write-kubeconfig-mode 644 --disable=traefik' sh -"
  log_success "Successfully installed k3s."
}

k3s_show_reinstall_warning() {
  spacer
  log_warn "k3s is already installed."
  log_warn "If you wish to reinstall k3s, please uninstall it with the following command:"
  log_warn "${BLUE}/usr/local/bin/k3s-uninstall.sh${NC}"
  log_warn "And run this script again."
  spacer
  if ! user_confirmed && ! prompt_yes_no "Do you wish to continue and re-apply the cluster configuration to the existing cluster?"; then
    graceful_exit 0
  fi
}

# =================================================================================================
# Kubernetes Helper Functions
# =================================================================================================

k8s_running() {
  kubectl get nodes &>/dev/null && return 0 || return 1
}

k8s_set_context_to_new_cluster() {
  # set the cluster context based on the cluster type
  log_info "Setting kubectl context to new cluster..."
  run_command "unset KUBECONFIG"
  run_command "kubectl config unset current-context"
  run_command "kubectl config use-context default"
  case $CLUSTER_TYPE in
    aws ) k8s_set_context_to_aws_cluster;;
    digital-ocean ) k8s_set_context_to_digital_ocean_cluster;;
    k3s ) k8s_set_context_k3s_cluster;;
    * ) log_error "Unknown cluster type: $CLUSTER_TYPE"; graceful_exit 1;;
  esac
}

k8s_set_context_to_aws_cluster() {
  cluster_name=$(terraform -chdir="$(terraform_dir)" output -raw aws_cluster_name)
  run_command "kubectl config delete-context $cluster_name &> /dev/null || true"
  run_command "aws eks --region $AWS_REGION update-kubeconfig --name $cluster_name"
}

k8s_set_context_to_digital_ocean_cluster() {
  cluster_name=$(terraform -chdir="$(terraform_dir)" output -raw do_cluster_name)
  cluster_id=$(terraform -chdir="$(terraform_dir)" output -raw do_cluster_id)
  log_info "Cluster name: $cluster_name"
  log_info "Cluster ID: $cluster_id"
  # run_command "kubectl config delete-context $cluster_name &> /dev/null || true"
  run_command "kubectl config delete-context $cluster_name || true"
  run_command "doctl kubernetes cluster kubeconfig save --alias $cluster_name $cluster_id"
}

k8s_set_context_k3s_cluster() {
  run_command "cp /etc/rancher/k3s/k3s.yaml $SCRIPT_DIR/../tmp/k3s.yaml"
  run_command "export KUBECONFIG=$ROOT_DIR/tmp/k3s.yaml"
  run_command "kubectl config rename-context default k3s-local"
}

k8s_clear_stale_kubectl_data() {
  spacer
  log_info "Clearing stale kubectl contexts, clusters, and users..."
  run_command "kubectl config get-contexts -o name | grep '$PROJECT_NAME' | xargs -I {} kubectl config delete-context {}"
  run_command "kubectl config get-clusters -o name | grep '$PROJECT_NAME' | xargs -I {} kubectl config delete-cluster {}"
  run_command "kubectl config get-users -o name | grep '$PROJECT_NAME' | xargs -I {} kubectl config delete-user {}"
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
  echo -e "To access the Kubernetes dashboard, go to the URL below in your browser and enter the token when prompted.\n\n${BLUE}http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/#/workloads?namespace=_all${NC}"
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
  START_TIME=$(date +%s)
  while true; do
    CURRENT_TIME=$(date +%s)
    ELAPSED_TIME=$((CURRENT_TIME - START_TIME))
    if [[ $ELAPSED_TIME -gt $POD_TIMEOUT ]]; then
      log_error "Timed out after waiting $POD_TIMEOUT seconds for pod with labels [$labels] to be ready."
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
  log_error "Timed out after waiting $POD_TIMEOUT seconds for pod with labels [$labels] to be ready."
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

  log_success "Dashboard installed and admin user created."
}

k8s_install_traefik() {
  log_info "Installing Traefik..."
  set_docker_hub_secret "traefik"
  run_command "helm repo add traefik https://helm.traefik.io/traefik"
  run_command "helm repo update"
  values_file="$SCRIPT_DIR/../kubernetes/helm/values/traefik/traefik-values.yaml"
  command="helm upgrade --install --create-namespace --values=$values_file -n traefik traefik traefik/traefik"
  run_command "$command"
  k8s_wait_for_pod "traefik" "app.kubernetes.io/name=traefik"
  dashboard_file="$SCRIPT_DIR/../kubernetes/deployments/traefik/traefik-dashboard.yaml"
  command="cat '$dashboard_file' | sed 's/KUBERNETES_HOSTNAME/Host(\`traefik.$LOCAL_HOSTNAME\`)/g' | kubectl apply -f -"
  run_command "$command"
  log_success "Successfully installed Traefik."
}

k8s_install_demo_apps() {
  set_docker_hub_secret "demo-apps"
  chart_folder="$SCRIPT_DIR/../kubernetes/helm/demo_app"
  values_folder="$SCRIPT_DIR/../kubernetes/helm/values/demo_apps"
  for values_file in "$values_folder"/*; do
    app=$(basename "$values_file" | sed 's/-values.yaml//g')
    log_info "Installing demo app: ${BLUE}$app${NC}"
    command="helm upgrade --install --create-namespace --values=$values_file --set ingress.host=$LOCAL_HOSTNAME --set git_sha=$(current_commit_sha) -n demo-apps $app $chart_folder"
    run_command "$command"
  done

  if ! k8s_wait_for_pod "demo-apps" "app=timestamp"; then
    log_error "Failed to install demo apps. Please try running this script again."
    graceful_exit 1
  fi
  log_success "Successfully installed demo apps."

}

k8s_set_up_dashboard_proxy() {
  spacer
  # prompt the user if they want to enable the dashboard proxy
  if ! prompt_yes_no "Would you like to enable the dashboard proxy?"; then
    return 0
  fi
  k8s_generate_token_for_admin_user
  k8s_start_proxy
  k8s_show_dashboard_access_instructions
}
# =================================================================================================
# Traefik Helper Functions
# =================================================================================================

traefik_set_endpoints() {
  lb_endpoint=$(kubectl get svc traefik -n traefik -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
  ip=$(kubectl get svc traefik -n traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
  # if the ip is empty, get the IP via dig and the load balancer endpoint
  if [ -z "$ip" ]; then
    # Try to resolve the endpoint as a domain name or IP address
    if [[ "$lb_endpoint" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      ip="$lb_endpoint"
    else
      ip=$(dig +short "$lb_endpoint" 2>/dev/null | head -n 1)

      # Check if the result is an IP address
      if ! [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        return 1
      fi
    fi
  fi
  export LOAD_BALANCER_ENDPOINT=$lb_endpoint
  export CLUSTER_ENDPOINT=$LOCAL_HOSTNAME
  export CLUSTER_IP=$ip
  return 0
}

traefik_wait_for_endpoint() {
  log_info "Waiting for Traefik load balancer to be ready..."
  START_TIME=$(date +%s)
  while true; do
    CURRENT_TIME=$(date +%s)
    ELAPSED_TIME=$((CURRENT_TIME - START_TIME))
    if [ $ELAPSED_TIME -gt $TRAEFIK_TIMEOUT ]; then
      spacer
      log_error "Timed out waiting for Traefik load balancer to be ready."
      graceful_exit 1
    fi

    if traefik_set_endpoints && curl -s -o /dev/null --fail "http://$CLUSTER_IP/dashboard/"; then
      echo ""
      log_success "Traefik load balancer is responding."
      return 0
    fi
    printf "."
    sleep 1
  done
}

report_access_points() {
  log_info "Gathering info about access points for Traefik and demo apps..."
  traefik_wait_for_endpoint
  app_hosts=$(kubectl get ingress -n demo-apps -o jsonpath='{.items[*].spec.rules[*].host}')
  log_info "You can access apps in the cluster at the following URLs:"
  if [ -n "$LOAD_BALANCER_ENDPOINT" ]; then
    log_info "Load balancer endpoint: ${BLUE}http://$LOAD_BALANCER_ENDPOINT${NC}"
  fi
  log_info "Cluster endpoint: ${BLUE}http://$CLUSTER_ENDPOINT${NC}"
  log_info "Cluster IP: ${BLUE}$CLUSTER_IP${NC}\n"
  log_info "Access points for Traefik and demo apps:"
  log_info "Traefik Dashboard URL: ${BLUE}http://traefik.$CLUSTER_ENDPOINT/${NC}\n"
  log_info "App URLs:"
  for app_host in $app_hosts; do
    log_info "${BLUE}http://$app_host${NC}"
  done

  spacer
  log_info "To access the Traefik dashboard and demo apps you'll need to add the following entries to your /etc/hosts file:"
  echo -e "${BLUE}$ip $CLUSTER_ENDPOINT${NC}"
  echo -e "${BLUE}$ip traefik.$CLUSTER_ENDPOINT${NC}"
  for app_host in $app_hosts; do
    echo -e "${BLUE}$ip $app_host${NC}"
  done
}
