####################################------------------------------------

### 1. Fetch Availability Zones
data "aws_availability_zones" "available" {
  state = "available"
}

#########################################---------
# 2. VPC Module
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "4.0.0"

  name = "prod-preview-vpc"
  cidr = var.vpc_cidr

  azs             = slice(data.aws_availability_zones.available.names, 0, 2)
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets

  enable_nat_gateway = true
  single_nat_gateway = true
}

#---------------------------
# 3. EKS Cluster Module (terraform-aws-modules/eks/aws v20.x)
module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "~> 18.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_group_defaults = {
    instance_types = [var.node_group_instance_type]
  }
  eks_managed_node_groups = {
    default = {
      desired_size = var.node_group_desired_capacity
      min_size     = 1
      max_size     = var.node_group_desired_capacity + 1
      key_name     = null
    }
  }

  cluster_endpoint_public_access        = true
  cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]

  map_users = [
    {
      userarn  = "arn:aws:iam::835990279052:user/admin-preyashyadav"
      username = "admin-preyashyadav"
      groups   = ["system:masters"]
    }
  ]
}







################################################################################
# 4. RDS PostgreSQL
################################################################################

# Subnet group so RDS lives in our private subnets
resource "aws_db_subnet_group" "default" {
  name       = "prod-preview-db-subnet-group"
  subnet_ids = module.vpc.private_subnets
}

# The actual Postgres instance
resource "aws_db_instance" "postgres" {
  identifier           = "prod-preview-db"
  engine               = "postgres"
  engine_version       = "14.18"
  instance_class       = var.db_instance_class
  allocated_storage    = var.db_allocated_storage
  db_name              = var.db_name      # was `name` previously—corrected here
  username             = var.db_username
  password             = var.db_password
  db_subnet_group_name = aws_db_subnet_group.default.name
  skip_final_snapshot  = true

  tags = {
    Name = "prod-preview-postgres"
  }
}
