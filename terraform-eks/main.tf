############################### VPC Module #######################
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-2a", "us-east-2b", "us-east-2c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  # Tags usadas pelo AWS Load Balancer Controller para descobrir as subnets.
  # ELB/ALB/NLB públicos usam as subnets públicas; LBs internos usam as privadas.
  public_subnet_tags = {
    "kubernetes.io/role/elb"      = "1"
    "kubernetes.io/cluster/orion" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
    "kubernetes.io/cluster/orion"     = "shared"
  }

  enable_nat_gateway = true
  single_nat_gateway = true
  enable_vpn_gateway = false

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}
############################## EKS Module ########################
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = "orion"
  kubernetes_version = "1.36"

  addons = {
    coredns = {}
    eks-pod-identity-agent = {
      before_compute = true
    }
    kube-proxy = {}
    vpc-cni = {
      before_compute = true
    }
  }

  # Desabilita os logs do control plane e o log group do CloudWatch para este teste.
  enabled_log_types           = []
  create_cloudwatch_log_group = false

  # Optional
  endpoint_public_access       = true
  endpoint_private_access      = true
  endpoint_public_access_cidrs = ["0.0.0.0/0"]

  # Optional: Adds the current caller identity as an administrator via cluster access entry
  enable_cluster_creator_admin_permissions = true

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = [module.vpc.private_subnets[0], module.vpc.private_subnets[1], module.vpc.private_subnets[2]]
  control_plane_subnet_ids = [module.vpc.private_subnets[0], module.vpc.private_subnets[1], module.vpc.private_subnets[2]]

  # EKS Managed Node Group(s)
  eks_managed_node_groups = {
    default = {
      # Starting on 1.30, AL2023 is the default AMI type for EKS managed node groups
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = ["t3.small"]

      min_size     = 2
      max_size     = 10
      desired_size = 2
    }
  }

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}
