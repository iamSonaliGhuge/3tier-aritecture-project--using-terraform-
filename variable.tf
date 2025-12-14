// VPC and Subnet variables for a three-tier architecture

variable "vpc_cidr" {
    description = "Primary VPC CIDR block"
    type        = string
    default     = "10.0.0.0/16"
}

variable "az_count" {
    description = "Number of Availability Zones (subnets per tier) to create"
    type        = number
    default     = 1
}

// Optional static lists. If left empty, subnets are computed from `vpc_cidr` using `cidrsubnet()`.
variable "public_subnets" {
    description = "Optional list of public subnet CIDRs. When empty, computed from `vpc_cidr` and `az_count`."
    type        = list(string)
    default     = []
}

variable "private_subnets" {
    description = "Optional list of private (app) subnet CIDRs. When empty, computed from `vpc_cidr` and `az_count`."
    type        = list(string)
    default     = []
}

variable "db_subnets" {
    description = "Optional list of DB/isolated subnet CIDRs. When empty, computed from `vpc_cidr` and `az_count`."
    type        = list(string)
    default     = []
}

locals {
    az_count = var.az_count

    # We derive /24 subnets from a /16 VPC (newbits = 8 -> /16 + 8 = /24).
    # Adjust `newbits` if you want larger/smaller subnet sizes (e.g. newbits = 6 for /22).
    computed_public_subnets  = [for i in range(local.az_count) : cidrsubnet(var.vpc_cidr, 8, i)]
    computed_private_subnets = [for i in range(local.az_count) : cidrsubnet(var.vpc_cidr, 8, i + local.az_count)]
    computed_db_subnets      = [for i in range(local.az_count) : cidrsubnet(var.vpc_cidr, 8, i + local.az_count * 2)]

    public_subnet_cidrs  = length(var.public_subnets)  > 0 ? var.public_subnets  : local.computed_public_subnets
    private_subnet_cidrs = length(var.private_subnets) > 0 ? var.private_subnets : local.computed_private_subnets
    db_subnet_cidrs      = length(var.db_subnets)     > 0 ? var.db_subnets     : local.computed_db_subnets
}

variable "project_name" {
    description = "Three-tier architecture project name"
    type        = string
    default     = "three-tier-vpc"
}

variable "aws_region" {
    description = "AWS region"
    type        = string
    default     = "us-east-1"
}

variable "igw_cidr" {
    description = "CIDR block for Internet Gateway route"
    type        = string
    default     = "0.0.0.0/0"
}

variable "ami" {
    description = "AMI ID for EC2 instances"
    type        = string
    default     = "ami-0ecb62995f68bb549"
}

variable "instance_type" {
    description = "EC2 instance type"
    type        = string
    default     = "t2.micro"
}