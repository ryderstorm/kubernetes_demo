#!/bin/bash

# =================================================================================================
# Set defaults
# =================================================================================================

# Set the AWS Region to use
if [ -z "$AWS_REGION" ]; then
  AWS_REGION="us-west-2"
fi

# Set EXIT_ON_ERROR if not already set
if [ -z "$EXIT_ON_ERROR" ]; then
  EXIT_ON_ERROR=true
fi

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
