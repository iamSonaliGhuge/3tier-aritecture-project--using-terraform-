terraform {
    required_version = ">= 1.0"
    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = "~> 5.0"
        }
    }
}

# Uncomment below after creating S3 bucket and configuring AWS credentials
terraform {
   backend "s3" {
     bucket = "threetierbucketts1132"
     key = "three-tier-vpc/terraform.tfstate"
     region = "us-east-1"
   }
 }

provider "aws" {
    region = var.aws_region
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "three-tier-vpc"
  }
}

# Public Subnets (Web Tier)
resource "aws_subnet" "public" {
  count                   = local.az_count
  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-${count.index + 1}"
  }
}

# Private Subnets (App Tier)
resource "aws_subnet" "private_app" {
  count             = local.az_count
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.private_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "private-app-subnet-${count.index + 1}"
  }
}

# Private Subnets (Database Tier)
resource "aws_subnet" "private_db" {
  count             = local.az_count
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.db_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "private-db-subnet-${count.index + 1}"
  }
}

# Data source for availability zones
data "aws_availability_zones" "available" {
    state = "available"
}

# create internet gateway
resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.main.id
    tags = {
        Name = "three-tier-igw"
    }
}
    # create default route table
resource "aws_default_route_table" "main_rt" {
    default_route_table_id = aws_vpc.main.default_route_table_id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw.id
    }   
    tags = {
      name = "${var.project_name}-main-rt"
    }
}

# create route in main route table 
resource "aws_route" "aws_route" {  
    route_table_id         = aws_default_route_table.main_rt.id
    destination_cidr_block = var.igw_cidr   
    gateway_id             = aws_internet_gateway.igw.id
}

# create a security group
resource "aws_security_group" "my_sg" { 
    vpc_id = aws_vpc.main.id
    name   = "${var.project_name}-sg"
    description = "allow inbound HTTP and SSH mysql traffic"
    ingress {
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        from_port   = 3306
        to_port     = 3306
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
        Name = "${var.project_name}-sg"
    }
    
    depends_on = [aws_vpc.main]
}
resource "aws_instance" "Public_Server" {
    ami           = var.ami # Amazon Linux 2 AMI
    instance_type = var.instance_type
    subnet_id     = aws_subnet.public[0].id
    vpc_security_group_ids = [aws_security_group.my_sg.id]
    tags = {
        Name = "${var.project_name}-App_Server"
    }
    depends_on = [ aws_security_group.my_sg ]
}
resource "aws_instance" "private_app_server" {
  ami = var.ami
  instance_type = var.instance_type
  subnet_id = aws_subnet.private_app[0].id
  vpc_security_group_ids = [aws_security_group.my_sg.id]
  tags = {
    Name = "${var.project_name}-db_Server"
  }
  depends_on = [ aws_security_group.my_sg ]
}
resource "aws_instance" "private_web_server" {
  ami = var.ami
  instance_type = var.instance_type
  subnet_id = aws_subnet.private_app[0].id
  vpc_security_group_ids = [aws_security_group.my_sg.id]
  tags = {
    Name = "${var.project_name}-web_Server"
  }
  depends_on = [ aws_security_group.my_sg ]
}