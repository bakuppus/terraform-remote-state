##################################################################################
# CONFIGURATION (for Terraform > 0.12)
###################################################################################
#provider
###################################################################################

provider "aws" {
  shared_credentials_file = "C:\\Users\\BALASUBRAMANI\\.aws\\config"
  profile = var.profile
  region     = var.region
}

terraform {
  required_version = ">= 0.13"

  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.7.0"
    }
  }
}
###################################################################################
#AWS IAM Module
###################################################################################

module "iam" {
  source  = "terraform-aws-modules/iam/aws"
  version = "2.3.0"
}

#-----------------------------------
# IAM users
#-----------------------------------
module "eks-admin" {
  source = "terraform-aws-modules/iam/aws//modules/iam-user"
  version = "~> 2.0"

  name = "eks-admin"

  create_iam_user_login_profile = false
  create_iam_access_key         = true
}

module "eks-developer" {
  source = "terraform-aws-modules/iam/aws//modules/iam-user"
  version = "~> 2.0"

  name = "eks-developer"

  create_iam_user_login_profile = false
  create_iam_access_key         = true

}

#-----------------------------------
# IAM group
#-----------------------------------
module "eks-admin-group" {
  source = "terraform-aws-modules/iam/aws//modules/iam-group-with-policies"
  version = "~> 2.0"

  name = "eks-admin-group"

  group_users = [
    module.eks-admin.this_iam_user_name,
  ]

  custom_group_policies = [
    {
      name   = "EKS-Cluster-Admin-Policy"
      policy = data.aws_iam_policy_document.policy_eks_admin.json
      PolicyDescription = "EKS cluster eks-admin access Policy"
    },
  ]
}

module "eks-developer-group" {
  source = "terraform-aws-modules/iam/aws//modules/iam-group-with-policies"
  version = "~> 2.0"

  name = "eks-developer-group"

  group_users = [
    module.eks-developer.this_iam_user_name,
  ]

  custom_group_policies = [
    {
      name   = "EKS-Cluster-Developer-Policy"
      policy = data.aws_iam_policy_document.policy_eks_developer.json
      PolicyDescription = "EKS cluster eks-developer access Policy"
    },
  ]
}


#-----------------------------------
# IAM policy
#-----------------------------------
data "aws_iam_policy_document" "policy_eks_admin" {
  statement {
    sid    = "OverridePlaceHolderOne"
    effect = "Allow"

    actions   = ["eks:*"]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "policy_eks_developer" {
  statement {
    sid    = "OverridePlaceHolderTwo"
    effect = "Allow"

    actions   = [
      "eks:DescribeNodegroup",
      "eks:ListNodegroups",
      "eks:DescribeCluster",
      "eks:ListClusters",
      "eks:AccessKubernetesApi",
      "ssm:GetParameter",
      "eks:ListUpdates",
      "eks:ListFargateProfiles"
    ]
    resources = ["*"]
  }
}



##################################################################################
# Management Security group
##################################################################################

resource "aws_security_group" "worker_group_mgmt_one" {
  name_prefix = "worker_group_mgmt_one"
  vpc_id      = var.vpc_id

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"

    cidr_blocks = [
      "0.0.0.0/0",
    ]
  }

  ingress {
    from_port = 2049
    to_port   = 2049
    protocol  = "tcp"

    cidr_blocks = [
      "0.0.0.0/0",
    ]
  }
  ingress {
    from_port = 5671
    to_port   = 5671
    protocol  = "tcp"

    cidr_blocks = [
      "0.0.0.0/0",
    ]
  }
  ingress {
    from_port = 443
    to_port   = 443
    protocol  = "tcp"

    cidr_blocks = [
      "0.0.0.0/0",
    ]
  }
  ingress {
    from_port = 80
    to_port   = 80
    protocol  = "tcp"

    cidr_blocks = [
      "0.0.0.0/0",
    ]
  }
}
##################################################################################
# DATA
##################################################################################
data "aws_eks_cluster" "cluster" {
  name = module.aws-eks-kubernetes-cluster.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.aws-eks-kubernetes-cluster.cluster_id
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token


  exec {
    api_version = "client.authentication.k8s.io/v1alpha1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      data.aws_eks_cluster.cluster.name
    ]
  }
}

provider "kubectl" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
  load_config_file       = false

  exec {
    api_version = "client.authentication.k8s.io/v1alpha1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      data.aws_eks_cluster.cluster.name
    ]
  }
}

###################################################################################
#AWS EKS Module
###################################################################################

module "aws-eks-kubernetes-cluster" {
  source          = "terraform-aws-modules/eks/aws"
  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version
  subnets         = var.private_subnets
  vpc_id          = var.vpc_id



  worker_groups = [
    {
      name = "worker-group-1"
      instance_type = var.instance_type_large
      key_name = var.key_name
      asg_min_size = var.asg_min_size_large
      asg_max_size  = var.asg_max_size_large
      asg_desired_capacity = var.asg_desired_capacity_large
      bootstrap_extra_args = "--container-runtime containerd"
      additional_security_group_ids = [aws_security_group.worker_group_mgmt_one.id]
      root_volume_size       = var.root_volume_size
      root_volume_type       = var.root_volume_type
      root_volume_throughput = var.root_volume_throughput
    },
    {
      name = "worker-group-2"
      instance_type = var.instance_type_xlarge
      key_name = var.key_name
      asg_min_size = var.asg_min_size_xlarge
      asg_max_size  = var.asg_max_size_xlarge
      asg_desired_capacity = var.asg_desired_capacity_xlarge
      bootstrap_extra_args = "--container-runtime containerd"
      additional_security_group_ids = [aws_security_group.worker_group_mgmt_one.id]
      root_volume_size       = var.root_volume_size
      root_volume_type       = var.root_volume_type
      root_volume_throughput = var.root_volume_throughput
    }
  ]

##################################################################################
# RBAC Map Account, Users
##################################################################################
  map_accounts = [
    "693310501970",
    "338828422527",
    "835482531307",
    "142281888524",
  ]

  map_users = [
    {
      userarn = module.eks-admin.this_iam_user_arn
      username = module.eks-admin.this_iam_user_name
      groups   = ["system:masters"]
    },
    {
      userarn  = module.eks-developer.this_iam_user_arn
      username = module.eks-developer.this_iam_user_name
      groups   = ["eks-console-dashboard-restricted-access-group", "eks-restricted-access-role-group"]
    },
  ]
}

##################################################################################
## RBAC Security
##################################################################################
data "kubectl_filename_list" "manifests_rbac" {
  pattern = "./manifests/rbac/*.yaml"
}

resource "kubectl_manifest" "apply_rbac" {
  depends_on = [module.aws-eks-kubernetes-cluster]
  count     = length(data.kubectl_filename_list.manifests_rbac.matches)
  yaml_body = file(element(data.kubectl_filename_list.manifests_rbac.matches, count.index))
}

##################################################################################
## END of Code
##################################################################################
