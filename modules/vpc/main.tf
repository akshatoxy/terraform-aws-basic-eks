resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"

  tags = (tomap({
    "Name" = "terraform-eks-vpc",
    "kubernetes.io/cluster/${var.cluster-name}" = "shared",
  }))
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "terraform-eks-igw"
  }
}

resource "aws_subnet" "public-subnet" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  
  tags = (tomap({
    "Name" = "terraform-eks-public-subnet",
    "kubernetes.io/cluster/${var.cluster-name}" = "shared",
  }))
}

resource "aws_route_table" "public-rtb" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "terraform-eks-public-rtb"
  }
}

resource "aws_route_table_association" "public-rtba" {
  route_table_id = aws_route_table.public-rtb.id
  subnet_id      = aws_subnet.public-subnet.id
}

resource "aws_subnet" "private-subnet" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"

  tags = (tomap({
    "Name" = "terraform-eks-private-subnet",
    "kubernetes.io/cluster/${var.cluster-name}" = "shared",
  }))
}

resource "aws_route_table" "private-rtb" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "terraform-eks-private-rtb"
  }
}

resource "aws_route_table_association" "private-rtba" {
  route_table_id = aws_route_table.private-rtb.id
  subnet_id      = aws_subnet.private-subnet.id
}
