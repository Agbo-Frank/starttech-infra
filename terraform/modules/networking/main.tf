data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.title}-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.title}-igw"
  }
}

resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.title}-public-subnet-1"
  }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.title}-public-subnet-2"
  }
}

resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "${var.title}-private-subnet-1"
  }
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "${var.title}-private-subnet-2"
  }
}

resource "aws_eip" "nat_eips" {
  for_each = toset(["subnet_1", "subnet_2"])
  domain   = "vpc"

  tags = {
    Name = "${var.title}-nat-eip-${each.key}"
  }
}

resource "aws_nat_gateway" "mains" {
  for_each = {
    subnet_1 = aws_subnet.public_subnet_1.id
    subnet_2 = aws_subnet.public_subnet_2.id
  }
  subnet_id         = each.value
  connectivity_type = "public"
  allocation_id     = aws_eip.nat_eips[each.key].id

  tags = {
    Name = "${var.title}-nat-${each.key}"
  }

  depends_on = [aws_internet_gateway.main]
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.title}-public-rt"
  }
}

resource "aws_route_table_association" "public_rt_associations" {
  for_each = {
    subnet_1 = aws_subnet.public_subnet_1.id
    subnet_2 = aws_subnet.public_subnet_2.id
  }

  subnet_id      = each.value
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table" "private_rt" {
  for_each = toset(["subnet_1", "subnet_2"])
  vpc_id   = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.mains[each.key].id
  }

  tags = {
    Name = "${var.title}-private-rt-${each.key}"
  }
}

resource "aws_route_table_association" "private_rt_associations" {
  for_each = {
    subnet_1 = aws_subnet.private_subnet_1.id
    subnet_2 = aws_subnet.private_subnet_2.id
  }

  subnet_id      = each.value
  route_table_id = aws_route_table.private_rt[each.key].id
}

# Load Balancer Security Group
resource "aws_security_group" "lb_sg" {
  name        = "${var.title}-lb-sg"
  description = "Allow HTTP and HTTPS from internet to load balancer"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.title}-lb-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "lb_allow_http" {
  security_group_id = aws_security_group.lb_sg.id
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "lb_allow_https" {
  security_group_id = aws_security_group.lb_sg.id
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "lb_allow_all_outbound" {
  security_group_id = aws_security_group.lb_sg.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# Web/Backend Security Group
resource "aws_security_group" "web_sg" {
  name        = "${var.title}-web-sg"
  description = "Allow traffic from ALB to backend EC2 instances"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.title}-web-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "web_allow_from_lb" {
  security_group_id            = aws_security_group.web_sg.id
  referenced_security_group_id = aws_security_group.lb_sg.id
  from_port                    = 8080
  to_port                      = 8080
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "web_allow_all_outbound" {
  security_group_id = aws_security_group.web_sg.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# ElastiCache Security Group
resource "aws_security_group" "cache_sg" {
  name        = "${var.title}-cache-sg"
  description = "Allow Redis traffic from backend EC2 instances only"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.title}-cache-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "cache_allow_from_web" {
  security_group_id            = aws_security_group.cache_sg.id
  referenced_security_group_id = aws_security_group.web_sg.id
  from_port                    = 6379
  to_port                      = 6379
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "cache_allow_all_outbound" {
  security_group_id = aws_security_group.cache_sg.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
