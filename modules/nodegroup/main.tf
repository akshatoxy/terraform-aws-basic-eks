data "aws_ami" "eks-worker" {
  filter {
    name   = "name"
    values = ["amazon-eks-node-${var.cluster.version}-v*"]
  }

  most_recent = true
  owners      = ["602401143452"] # Amazon EKS AMI Account ID
}

locals {
  demo-node-userdata = <<USERDATA
#!/bin/bash
set -o xtrace
/etc/eks/bootstrap.sh --apiserver-endpoint '${var.cluster.endpoint}' --b64-cluster-ca '${var.cluster.certificate_authority.0.data}' '${var.cluster-name}'
USERDATA
}

resource "aws_iam_role" "nodegroup-role" {
  name = "terraform-eks-nodegroup-role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "demo-node-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.nodegroup-role.name
}

resource "aws_iam_role_policy_attachment" "demo-node-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.nodegroup-role.name
}

resource "aws_iam_role_policy_attachment" "demo-node-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.nodegroup-role.name
}

resource "aws_iam_instance_profile" "nodegroup-profile" {
  name = "terraform-eks-nodegroup-profile"
  role = aws_iam_role.nodegroup-role.name
}

resource "aws_security_group" "nodegroup-sg" {
  name        = "terraform-eks-nodegroup-sg"
  description = "Security group for all nodes in the cluster"
  vpc_id      = var.vpc-id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [var.master-sg-id]
  }

  ingress {
    from_port       = 1025
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [var.master-sg-id]
  }

  tags = (tomap({
    "Name" = "terraform-eks-nodegroup-sg",
    "kubernetes.io/cluster/${var.cluster-name}" = "owned",
  }))
}

resource "aws_security_group_rule" "nodegroup-sg-rule" {
  description              = "Allow node to communicate with each other"
  from_port                = 0
  protocol                 = "-1"
  security_group_id        = "${aws_security_group.nodegroup-sg.id}"
  source_security_group_id = "${aws_security_group.nodegroup-sg.id}"
  to_port                  = 65535
  type                     = "ingress"
}

resource "aws_eks_node_group" "nodegroup" {
  cluster_name    = var.cluster-name
  node_group_name = "terraform-eks-nodegroup"
  node_role_arn   = aws_iam_role.nodegroup-role.arn
  subnet_ids      = [var.public-subnet-id]
  instance_types = ["t2.micro"]

  scaling_config {
    desired_size = 1
    min_size     = 1
    max_size     = 3
  }

  depends_on = [
    aws_iam_role_policy_attachment.demo-node-AmazonEC2ContainerRegistryReadOnly,
    aws_iam_role_policy_attachment.demo-node-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.demo-node-AmazonEKSWorkerNodePolicy
  ]
}

resource "aws_launch_configuration" "nodegroup-alc" {
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.nodegroup-profile.name
  image_id                    = data.aws_ami.eks-worker.id
  instance_type               = "t2.micro"
  security_groups             = [aws_security_group.nodegroup-sg.id]
  user_data_base64            = base64encode(local.demo-node-userdata)

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "nodegroup-asg" {
  desired_capacity     = 1
  max_size             = 2
  min_size             = 1
  launch_configuration = aws_launch_configuration.nodegroup-alc.id
  name                 = "terraform-eks-asg"
  vpc_zone_identifier  = [var.public-subnet-id]

  tag {
    key                 = "Name"
    value               = "terraform-eks-asg"
    propagate_at_launch = true
  }

  tag {
    key                 = "kubernetes.io/cluster/${var.cluster-name}"
    value               = "owned"
    propagate_at_launch = true
  }
}
