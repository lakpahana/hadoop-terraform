provider "aws" {
  region = var.aws_region
}

# VPC Configuration
resource "aws_vpc" "hadoop_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "hadoop-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "hadoop_igw" {
  vpc_id = aws_vpc.hadoop_vpc.id

  tags = {
    Name = "hadoop-igw"
  }
}

# Public Subnet
resource "aws_subnet" "hadoop_public_subnet" {
  vpc_id                  = aws_vpc.hadoop_vpc.id
  cidr_block              = var.public_subnet_cidr
  map_public_ip_on_launch = true
  availability_zone       = "${var.aws_region}a"

  tags = {
    Name = "hadoop-public-subnet"
  }
}

# Route Table
resource "aws_route_table" "hadoop_public_rt" {
  vpc_id = aws_vpc.hadoop_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.hadoop_igw.id
  }

  tags = {
    Name = "hadoop-public-rt"
  }
}

# Route Table Association
resource "aws_route_table_association" "hadoop_public_rt_assoc" {
  subnet_id      = aws_subnet.hadoop_public_subnet.id
  route_table_id = aws_route_table.hadoop_public_rt.id
}

# Security Group
resource "aws_security_group" "hadoop_sg" {
  name        = "hadoop-security-group"
  description = "Security group for Hadoop cluster"
  vpc_id      = aws_vpc.hadoop_vpc.id

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Hadoop ports
  ingress {
    from_port   = 8020
    to_port     = 8020
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    from_port   = 50070
    to_port     = 50070
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    from_port   = 8088
    to_port     = 8088
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Allow all internal VPC traffic
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "hadoop-security-group"
  }
}

# Master Node
resource "aws_instance" "hadoop_master" {
  ami           = var.ami
  instance_type = var.instance_type
  key_name      = var.key_name
  subnet_id     = aws_subnet.hadoop_public_subnet.id

  vpc_security_group_ids = [aws_security_group.hadoop_sg.id]

  root_block_device {
    volume_size = 30
    volume_type = "gp2"
  }
  user_data = templatefile("${path.module}/scripts/master-setup.sh", {
    worker_count = var.worker_count,
    java_home = "/usr/lib/jvm/java-8-openjdk-amd64"
  })

  tags = {
    Name = "hadoop-master"
    Role = "master"
  }
}

# Worker Nodes
resource "aws_instance" "hadoop_workers" {
  count         = var.worker_count
  ami           = var.ami
  instance_type = var.instance_type
  key_name      = var.key_name
  subnet_id     = aws_subnet.hadoop_public_subnet.id

  vpc_security_group_ids = [aws_security_group.hadoop_sg.id]

  root_block_device {
    volume_size = 30
    volume_type = "gp2"
  }
  user_data = templatefile("${path.module}/scripts/worker-setup.sh", {
    master_ip = aws_instance.hadoop_master.private_ip,
    java_home = "/usr/lib/jvm/java-8-openjdk-amd64"
  })

  tags = {
    Name = "hadoop-worker-${count.index + 1}"
    Role = "worker"
  }

  depends_on = [aws_instance.hadoop_master]
}
