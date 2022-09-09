provider "aws" {
  region = "us-east-1"
}

module "vpc" {
  source       = ".\\modules\\vpc"
  cluster-name = var.cluster-name
}

module "nodegroup" {
  source = ".\\modules\\nodegroup"
  cluster-name = var.cluster-name
  public-subnet-id = module.vpc.public-subnet-id
  master-sg-id = aws_security_group.master-sg.id
  cluster = aws_eks_cluster.cluster
  vpc-id = module.vpc.vpc-id
}

resource "aws_iam_role" "cluster-iam-role" {
  name = "terraform-eks-master-role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "demo-cluster-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster-iam-role.name
}

resource "aws_iam_role_policy_attachment" "demo-cluster-AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.cluster-iam-role.name
}

resource "aws_security_group" "master-sg" {
  name        = "terraform-eks-master-sg"
  description = "Cluster communication with worker nodes"
  vpc_id      = module.vpc.vpc-id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["122.180.223.97/32"]
  }

  tags = {
    Name = "terraform-eks-master-sg"
  }
}

resource "aws_security_group_rule" "master-sg-rule" {
  description              = "Allow pods to communicate with the cluster API Server"
  from_port                = 443
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.master-sg.id}"
  source_security_group_id = "${module.nodegroup.sg-id}"
  to_port                  = 443
  type                     = "ingress"
}

resource "aws_eks_cluster" "cluster" {
  name     = var.cluster-name
  role_arn = aws_iam_role.cluster-iam-role.arn

  vpc_config {
    security_group_ids = ["${aws_security_group.master-sg.id}"]
    subnet_ids         = ["${module.vpc.public-subnet-id}", "${module.vpc.private-subnet-id}"]
  }

  depends_on = [
    aws_iam_role_policy_attachment.demo-cluster-AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.demo-cluster-AmazonEKSServicePolicy,
  ]

  tags = {
    Name = var.cluster-name
  }
}
