

// VPC

// Discover Subnets that have the private tag

data "aws_subnets" "private_subs" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
  tags = {
    private = "1"
  }
}


// setup var for first 3 existing private subnets

data "aws_subnet" "sub1" {
  id = data.aws_subnets.private_subs.ids[0]
}

data "aws_subnet" "sub2" {
  id = data.aws_subnets.private_subs.ids[1]
}

data "aws_subnet" "sub3" {
  id = data.aws_subnets.private_subs.ids[2]
}




// Add Private NATGW to routable subnets

resource "aws_nat_gateway" "eks_priv_natgw" {
  for_each          = toset(data.aws_subnets.private_subs.ids)
  connectivity_type = "private"
  subnet_id         = each.key
  tags = {
    Name    = "Private NATGW - ${each.key}"
    private = "1"
  }

}



# Add EKS CIDR to VPC

resource "aws_vpc_ipv4_cidr_block_association" "eks_cidr_assoc" {
  vpc_id     = var.vpc_id
  cidr_block = var.eks_cidr
}





// compute CIDR blocks
module "subnet_addrs" {
  source = "hashicorp/subnets/cidr"

  base_cidr_block = var.eks_cidr
  networks = [
    {
      name     = "${var.cluster_name}-subnet1"
      new_bits = 6
    },
    {
      name     = "${var.cluster_name}-subnet2"
      new_bits = 6
    },
    {
      name     = "${var.cluster_name}-subnet3"
      new_bits = 6
    },
  ]
}


// add subnets
resource "aws_subnet" "eks-subnet1" {

  vpc_id            = var.vpc_id
  availability_zone = data.aws_subnet.sub1.availability_zone
  cidr_block        = module.subnet_addrs.network_cidr_blocks["${var.cluster_name}-subnet1"]
  depends_on = [
    aws_vpc_ipv4_cidr_block_association.eks_cidr_assoc
  ]

  tags = {
    Name                                        = "${var.cluster_name}-subnet1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = "1"
    "karpenter.sh/discovery"                    = var.cluster_name
  }

}


resource "aws_subnet" "eks-subnet2" {

  vpc_id            = var.vpc_id
  availability_zone = data.aws_subnet.sub2.availability_zone
  cidr_block        = module.subnet_addrs.network_cidr_blocks["${var.cluster_name}-subnet2"]
  depends_on = [
    aws_vpc_ipv4_cidr_block_association.eks_cidr_assoc
  ]

  tags = {
    Name                                        = "${var.cluster_name}-subnet2"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = "1"
    "karpenter.sh/discovery"                    = var.cluster_name
  }

}


resource "aws_subnet" "eks-subnet3" {

  vpc_id            = var.vpc_id
  availability_zone = data.aws_subnet.sub3.availability_zone
  cidr_block        = module.subnet_addrs.network_cidr_blocks["${var.cluster_name}-subnet3"]
  depends_on = [
    aws_vpc_ipv4_cidr_block_association.eks_cidr_assoc
  ]

  tags = {
    Name                                        = "${var.cluster_name}-subnet3"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = "1"
    "karpenter.sh/discovery"                    = var.cluster_name
  }

}





// add routing tables and associations



// Discover public NAT gateways 

data "aws_nat_gateways" "natgw-pub1" {
  vpc_id = var.vpc_id

  filter {
    name   = "state"
    values = ["available"]
  }
  filter {
    name   = "subnet-id"
    values = [data.aws_subnet.sub1.id]
  }
  tags = {
    public = "1"
  }
}

data "aws_nat_gateways" "natgw-pub2" {
  vpc_id = var.vpc_id

  filter {
    name   = "state"
    values = ["available"]
  }
  filter {
    name   = "subnet-id"
    values = [data.aws_subnet.sub2.id]
  }
  tags = {
    public = "1"
  }
}


data "aws_nat_gateways" "natgw-pub3" {
  vpc_id = var.vpc_id

  filter {
    name   = "state"
    values = ["available"]
  }
  filter {
    name   = "subnet-id"
    values = [data.aws_subnet.sub3.id]
  }
  tags = {
    public = "1"
  }
}






// Create route tables and associate

// route table 1
resource "aws_route_table" "sub1-rt" {
  vpc_id = var.vpc_id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = data.aws_nat_gateways.natgw-pub1.ids[0]
  }
  route {
    cidr_block     = "10.0.0.0/8"
    nat_gateway_id = aws_nat_gateway.eks_priv_natgw[data.aws_subnet.sub1.id].id
  }
  route {
    cidr_block     = "172.16.0.0/12"
    nat_gateway_id = aws_nat_gateway.eks_priv_natgw[data.aws_subnet.sub1.id].id
  }
  route {
    cidr_block     = "192.168.0.0/16"
    nat_gateway_id = aws_nat_gateway.eks_priv_natgw[data.aws_subnet.sub1.id].id
  }

}

resource "aws_route_table_association" "sub1-rta" {
  subnet_id      = aws_subnet.eks-subnet1.id
  route_table_id = aws_route_table.sub1-rt.id
}


// route table 2
resource "aws_route_table" "sub2-rt" {
  vpc_id = var.vpc_id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = data.aws_nat_gateways.natgw-pub2.ids[0]
  }
  route {
    cidr_block     = "10.0.0.0/8"
    nat_gateway_id = aws_nat_gateway.eks_priv_natgw[data.aws_subnet.sub2.id].id
  }
  route {
    cidr_block     = "172.16.0.0/12"
    nat_gateway_id = aws_nat_gateway.eks_priv_natgw[data.aws_subnet.sub2.id].id
  }
  route {
    cidr_block     = "192.168.0.0/16"
    nat_gateway_id = aws_nat_gateway.eks_priv_natgw[data.aws_subnet.sub2.id].id
  }

}

resource "aws_route_table_association" "sub2-rta" {
  subnet_id      = aws_subnet.eks-subnet2.id
  route_table_id = aws_route_table.sub2-rt.id
}



// route table 3
resource "aws_route_table" "sub3-rt" {
  vpc_id = var.vpc_id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = data.aws_nat_gateways.natgw-pub3.ids[0]
  }
  route {
    cidr_block     = "10.0.0.0/8"
    nat_gateway_id = aws_nat_gateway.eks_priv_natgw[data.aws_subnet.sub3.id].id
  }
  route {
    cidr_block     = "172.16.0.0/12"
    nat_gateway_id = aws_nat_gateway.eks_priv_natgw[data.aws_subnet.sub3.id].id
  }
  route {
    cidr_block     = "192.168.0.0/16"
    nat_gateway_id = aws_nat_gateway.eks_priv_natgw[data.aws_subnet.sub3.id].id
  }

}

resource "aws_route_table_association" "sub3-rta" {
  subnet_id      = aws_subnet.eks-subnet3.id
  route_table_id = aws_route_table.sub3-rt.id
}



