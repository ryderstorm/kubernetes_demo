# This is set by TF_VAR_aws_region in lib/set_envs.sh
variable "aws_region" {
  description = "AWS region"
  type        = string
}

# This is set by TF_VAR_project_name in lib/set_envs.sh
variable "project_name" {
  description = "Project name"
  type        = string
}

variable "instance_types" {
  description = "Instance types for EKS nodes"
  type        = list(string)
  default     = ["t3.medium"]
}
