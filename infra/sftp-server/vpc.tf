
resource "aws_vpc" "this" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "sftp-vpc"
  }  
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "sftp-igw"
  }    
}

resource "aws_subnet" "public" {
  count                   = length(var.az_list)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(aws_vpc.this.cidr_block, 8, count.index)
  map_public_ip_on_launch = true
  availability_zone       = var.az_list[count.index]
  tags = {
    Name = "sftp-subnet-${count.index}"
  }   
}

resource "aws_eip" "static_sftp_ip" {
  count = length(var.az_list)
  tags = {
    Name = "sftp-static-ip"
  }
}


resource "aws_route_table" "this" {
  count  = length(var.az_list)
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "sftp-rt-${count.index}"
  }     
}

resource "aws_route_table_association" "this" {
  count          = length(var.az_list)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.this[count.index].id
}

resource "aws_route" "subnet_to_igw" {
  count                  = length(var.az_list)
  route_table_id         = aws_route_table.this[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_security_group" "sftp_sg" {
  vpc_id = aws_vpc.this.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_incoming_cidr_list  # Only allow incoming from fixed IP
  }

  tags = {
    Name = "sftp-sg"
  }     
}
