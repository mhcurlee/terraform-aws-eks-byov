// EKS module 


locals {
  cluster_name    = var.cluster_name
  node_group_name = "ng1"
}



data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}


data "aws_caller_identity" "current" {}

locals {
  role_principal_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
}


# add roles for k8s access

resource "aws_iam_role" "k8s-admin-role" {
  name = "eks-k8s-admin-role-${local.cluster_name}"


  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          "AWS" : "${local.role_principal_arn}"
        }
      },
    ]
  })

  tags = {
    tag-key = "EKS-${local.cluster_name}"
  }
}


resource "aws_iam_role" "k8s-dev-role" {
  name = "eks-k8s-dev-role-${local.cluster_name}"


  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          "AWS" : "${local.role_principal_arn}"
        }
      },
    ]
  })

  tags = {
    tag-key = "EKS-${local.cluster_name}"
  }
}

resource "aws_kms_key" "eks" {
  description             = "EKS Secret Key"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}



resource "aws_iam_policy" "efs-csi-node-policy" {
  name        = "efs-csi-node-policy"
  description = "EFS CIS policy for nodes"

  policy = jsonencode({

    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "elasticfilesystem:DescribeMountTargets",
          "ec2:DescribeAvailabilityZones"
        ],
        "Resource" : "*"
      }
    ]
  })
}




module "eks" {
  source                          = "terraform-aws-modules/eks/aws"
  version                         = "19.10.0"
  cluster_name                    = local.cluster_name
  cluster_version                 = "1.25"
  cluster_enabled_log_types       = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  vpc_id                          = var.vpc_id
  subnet_ids                      = [aws_subnet.eks-subnet1.id, aws_subnet.eks-subnet2.id, aws_subnet.eks-subnet3.id]
  enable_irsa                     = true
  create_cluster_security_group   = false
  create_node_security_group      = false
  manage_aws_auth_configmap       = true
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true
  cluster_service_ipv4_cidr       = "10.180.0.0/16"
  #control_plane_subnet_ids        = data.aws_subnets.private_subs.ids

  cluster_encryption_config = {
      provider_key_arn = aws_kms_key.eks.arn
      resources        = ["secrets"]
    }


  aws_auth_roles = [
    {
      rolearn  = aws_iam_role.k8s-admin-role.arn
      username = "admin-user"
      groups   = ["system:masters"]
    },
    {
      rolearn  = aws_iam_role.k8s-dev-role.arn
      username = "dev-user"
      groups   = [""]
    }
  ]



  eks_managed_node_groups = {
    (local.node_group_name) = {
      instance_types                        = ["t3.medium"]
      ami_type                              = "BOTTLEROCKET_x86_64"
      create_security_group                 = false
      attach_cluster_primary_security_group = true
      key_name                              = "ec2-ohio"
      disk_size                             = 80

      min_size     = 2
      max_size     = 2
      desired_size = 2

      
    }
  }

  tags = {
    # Tag node group resources for Karpenter auto-discovery
    # NOTE - if creating multiple security groups with this module, only tag the
    # security group that Karpenter should utilize with the following tag
    "karpenter.sh/discovery" = local.cluster_name
  }


}

