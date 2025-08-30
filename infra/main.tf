# --- VPC ---
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  tags = {
    Name = "diploma-vpc"
  }
}

# --- Subnet ---
resource "aws_subnet" "main" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet_cidr
  map_public_ip_on_launch = true
  availability_zone       = "${var.aws_region}a"
  tags = {
    Name = "diploma-subnet"
  }
}

# --- Internet Gateway ---
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "diploma-igw"
  }
}

# --- Route Table ---
resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = {
    Name = "diploma-rt"
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.rt.id
}

# --- Security Group ---
resource "aws_security_group" "diploma_sg" {
  vpc_id = aws_vpc.main.id
  name   = "diploma-sg"

  # SSH — только с твоего IP
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  # Prometheus — только с твоего IP
  ingress {
    description = "Prometheus UI"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  # Grafana — только с твоего IP
  ingress {
    description = "Grafana UI"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  # Исходящий трафик — открыт
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "diploma-sg"
  }
}

# --- EC2 Instance ---
resource "aws_instance" "app_server" {
  ami           = "ami-0e872aee57663ae2d" # Ubuntu 22.04 (eu-central-1)
  instance_type = var.instance_type
  subnet_id     = aws_subnet.main.id
  key_name      = var.key_name
  vpc_security_group_ids = [aws_security_group.diploma_sg.id]

  tags = {
    Name = "diploma-app"
  }
}