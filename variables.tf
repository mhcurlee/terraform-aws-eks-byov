variable "cluster_name" {
  description = "The name of the EKS cluster"
  type        = string
  default     = "marvin-test"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9\\-]*[a-z0-9]$", var.cluster_name))
    error_message = "Cluster name can only contain lower case letters, numbers, and hyphens.  The name must also start and end with a lower case alphanumeric character."
  }

  validation {
    condition     = length(var.cluster_name) < 101
    error_message = "Cluster name has a max size of 100 chars."
  }

}

variable "eks_cidr" {
  type        = string
  description = "CIDR block used for EKS"
  default     = "10.128.0.0/16"
}

variable "vpc_id" {
  type        = string
  description = "Existing target VPC ID"
  default     = "vpc-030de5a29123ed005"
}


