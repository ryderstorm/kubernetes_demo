#!/bin/bash

# =================================================================================================
# Set default environment variables
# =================================================================================================

# Set the AWS Region to use
if [ -z "$AWS_REGION" ]; then
  AWS_REGION="us-west-2"
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
