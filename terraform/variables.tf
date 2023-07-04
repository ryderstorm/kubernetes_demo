# This is set by TF_VAR_project_name in lib/set_envs.sh
variable "project_name" {
  description = "Project name"
  type        = string
}

# This is set by TF_VAR_aws_region in lib/set_envs.sh
variable "aws_region" {
  description = "AWS region"
  type        = string
}

# This is set by TF_VAR_aws_region in lib/set_envs.sh
variable "do_region" {
  description = "Digital Ocean region"
  type        = string
}

variable "aws_instance_types" {
  description = "Instance types for AWS EKS nodes"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "do_instance_types" {
  description = "Instance types for Digital Ocean nodes"
  type        = list(string)
  default     = ["s-2vcpu-2gb-amd"]
}

variable "selected_cloud_service" {
  description = "Cloud service specified by the user"
  type        = string
  default     = "aws"
}

# This is set by TF_VAR_do_token in lib/set_envs.sh
variable "do_token" {
  description = "Digital Ocean token"
  type        = string
}
