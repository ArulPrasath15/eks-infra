provider "aws" {
  region = var.region
}

# Define the base CIDR block for the VPC
variable "vpc_cidr" {
  description = "The CIDR block for the VPC"
  default     = "10.0.0.0/16"
}

# Create a VPC, subnets, and other necessary networking resources dynamically
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.11.0" # Ensure to check for the latest version

  name = "my-vpc"
  cidr = var.vpc_cidr

  azs = ["${var.region}a", "${var.region}b", "${var.region}c"]

  # Dynamically generate subnet CIDRs
  private_subnets = [for i in range(3) : cidrsubnet(var.vpc_cidr, 4, i + 1)]
  public_subnets  = [for i in range(3) : cidrsubnet(var.vpc_cidr, 4, i + 4)]

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# Create an EKS cluster and node group within the dynamically created VPC
module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "17.1.0" # Ensure to check for the latest version

  cluster_name    = var.cluster_name
  cluster_version = "1.21"
  subnets         = module.vpc.private_subnets
  vpc_id          = module.vpc.vpc_id

  node_groups = {
    example = {
      name             = var.node_group_name
      instance_type    = "m5.large"
      desired_capacity = 2
      max_capacity     = 3
      min_capacity     = 1
    }
  }
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_identity_oidc_issuer" {
  value = module.eks.cluster_identity_oidc_issuer
}

output "cluster_id" {
  value = module.eks.cluster_id
}
