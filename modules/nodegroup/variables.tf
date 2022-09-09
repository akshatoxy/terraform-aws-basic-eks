variable "cluster-name" {
  type    = string
  default = "terraform-eks-demo"
}

variable "public-subnet-id" {}
variable "master-sg-id" {}
variable "cluster" {}
variable "vpc-id" {}