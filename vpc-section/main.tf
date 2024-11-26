resource "random_string" "resource_suffix" {
  length  = 6
  upper   = false
  special = false
}

provider "aws" {
  region  = "ap-northeast-2"
  profile = var.aws_profile
}

# 기존 VPC 확인
data "aws_vpcs" "existing_vpcs" {}

# 기존 VPC CIDR 블록 가져오기
data "aws_vpc" "vpc_details" {
  count = length(data.aws_vpcs.existing_vpcs.ids)
  id    = data.aws_vpcs.existing_vpcs.ids[count.index]
}

# 기존 서브넷 CIDR 가져오기
data "aws_subnets" "existing_subnets" {}

data "aws_subnet" "subnet_details" {
  count = length(data.aws_subnets.existing_subnets.ids)
  id    = data.aws_subnets.existing_subnets.ids[count.index]
}

# 동적 CIDR 계산
locals {
  # 기존 CIDR 안전하게 가져오기 (data가 비어 있는 경우 빈 리스트)
  existing_cidrs = can(data.aws_vpcs.existing_vpcs.ids) && can(data.aws_subnets.existing_subnets.ids) ? concat(
    [for vpc in data.aws_vpc.vpc_details : vpc.cidr_block],
    [for subnet in data.aws_subnet.subnet_details : subnet.cidr_block]
  ) : []

  # 최대 생성 가능한 서브넷 개수 계산 (/12에서 newbits=4 → 최대 64개)
  max_subnets = pow(2, 12 - 4)

  # 새로운 VPC CIDR 계산 (CIDR 초과 또는 destroy 시 기본값 사용)
  new_vpc_cidr = (
    length(local.existing_cidrs) < local.max_subnets ?
    cidrsubnet(var.base_cidr, 4, length(local.existing_cidrs)) :
    var.base_cidr
  )
}


# VPC 생성
resource "aws_vpc" "my_vpc" {
  cidr_block           = local.new_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "${var.resource_name_prefix}-${random_string.resource_suffix.result}-vpc"
  }
}

# 인터넷 게이트웨이 생성
resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name = "${var.resource_name_prefix}-${random_string.resource_suffix.result}-igw"
  }
}

# 퍼블릭 서브넷 생성
resource "aws_subnet" "public_subnets" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = cidrsubnet(local.new_vpc_cidr, 4, count.index) # /20 서브넷 생성
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.resource_name_prefix}-${random_string.resource_suffix.result}-public-subnet-${count.index + 1}"
  }
}

# 프라이빗 서브넷 생성
resource "aws_subnet" "private_subnets" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = cidrsubnet(local.new_vpc_cidr, 4, count.index + 3) # /20 서브넷 생성
  availability_zone = var.availability_zones[count.index]
  tags = {
    Name = "${var.resource_name_prefix}-${random_string.resource_suffix.result}-private-subnet-${count.index + 1}"
  }
}

# NAT 게이트웨이 생성
resource "aws_eip" "ngw_eip" {
  domain = "vpc"
  tags = {
    Name = "${var.resource_name_prefix}-${random_string.resource_suffix.result}-ngw-eip"
  }
}

resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.ngw_eip.id
  subnet_id     = aws_subnet.public_subnets[0].id # 첫 번째 퍼블릭 서브넷에 배치
  tags = {
    Name = "${var.resource_name_prefix}-${random_string.resource_suffix.result}-nat-gateway"
  }
}

# 퍼블릭 라우팅 테이블 생성
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name = "${var.resource_name_prefix}-${random_string.resource_suffix.result}-public-route-table"
  }
}

# 퍼블릭 라우팅 테이블에 IGW 추가
resource "aws_route" "public_route" {
  route_table_id         = aws_route_table.public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.my_igw.id
}

# 퍼블릭 서브넷과 퍼블릭 라우팅 테이블 연결
resource "aws_route_table_association" "public_associations" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public_route_table.id
}

# 프라이빗 라우팅 테이블 생성
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name = "${var.resource_name_prefix}-${random_string.resource_suffix.result}-private-route-table"
  }
}

# 프라이빗 라우팅 테이블에 NAT 게이트웨이 추가
resource "aws_route" "private_route" {
  route_table_id         = aws_route_table.private_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gateway.id
}

# 프라이빗 서브넷과 프라이빗 라우팅 테이블 연결
resource "aws_route_table_association" "private_associations" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.private_subnets[count.index].id
  route_table_id = aws_route_table.private_route_table.id
}
