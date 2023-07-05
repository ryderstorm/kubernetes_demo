#!/bin/bash

# =================================================================================================
# Set default environment variables
# =================================================================================================

# Set the AWS Region to use
if [ -z "$AWS_REGION" ]; then
  # AWS_REGION="us-west-2"
  AWS_REGION="us-east-2"
  export TF_VAR_aws_region="$AWS_REGION"
fi

# Set EXIT_ON_ERROR if not already set
if [ -z "$EXIT_ON_ERROR" ]; then
  EXIT_ON_ERROR=true
fi

# Set the default user name for the AWS CLI
if [ -z "$IAM_USER_NAME" ]; then
  IAM_USER_NAME="xyz-demo-user"
fi

# Set the default policy name for the AWS CLI
if [ -z "$POLICY_NAME" ]; then
  POLICY_NAME="xyz-demo-policy"
fi

# Set the default policy file path for the AWS CLI
if [ -z "$POLICY_FILE_PATH" ]; then
  POLICY_FILE_PATH="config/iam_policy.json"
fi

# Set the defaul project name
if [ -z "$PROJECT_NAME" ]; then
  PROJECT_NAME="xyz-demo"
  export TF_VAR_project_name="$PROJECT_NAME"
fi

# Set the local host name for the k3s cluster
if [ -z "$LOCAL_HOSTNAME" ]; then
  LOCAL_HOSTNAME="k8s.local"
fi

# Set the list of demo apps to install
if [ -z "$DEMO_APPS" ]; then
  DEMO_APPS='"whoami" "nginx-hello" "timestamp" "ubuntu-testbed"'
fi

# Set the Docker repository
# Eventually this will be a private repository inside the Kubernetes cluster
# For now, it's a public repository on Docker Hub
# This also helsp to avoid rate limiting on Docker Hub
DOCKER_REPOSITORY="ryderstorm/xyz-demo"
