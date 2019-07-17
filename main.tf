provider "aws" {
  region     = "us-east-1"
  access_key = "XXXXXXXXXX"
  secret_key = "XXXXXXXXXXXXXXXXXXXXXXXXX"
}

resource "aws_vpc" "VPC100" {
  cidr_block       = "172.16.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "VPC100"
  }
}


resource "aws_default_route_table" "MainRoutingTable-VPC100" {
  default_route_table_id = "${aws_vpc.VPC100.default_route_table_id}"

  tags = {
    Name = "MainRoutingTable-VPC100"
  }
}

###############			Subnet			#########################
resource "aws_subnet" "Public" {
  vpc_id     = "${aws_vpc.VPC100.id}"
  cidr_block = "172.16.0.0/24"
  availability_zone = "us-east-1a"
  

  tags = {
    Name = "Public"
  }
}

resource "aws_subnet" "Private" {
  vpc_id     = "${aws_vpc.VPC100.id}"
  cidr_block = "172.16.1.0/24"
  availability_zone = "us-east-1a"
  

  tags = {
    Name = "Private"
  }
}

###############			IGW			#########################
resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.VPC100.id}"

  tags = {
    Name = "VPC100"
  }
}


################		Route Table	 ###################

resource "aws_route_table" "rt" {
  vpc_id = "${aws_vpc.VPC100.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gw.id}"
  }

  tags = {
    Name = "PublicRoutingTable"
  }
}

resource "aws_route_table" "privatert" {
  vpc_id = "${aws_vpc.VPC100.id}"

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = "${aws_nat_gateway.ngw.id}"
  }

  tags = {
    Name = "PrivateRoutingTable"
  }
}



################ Route table attach ############


resource "aws_route_table_association" "a" {
  subnet_id      = "${aws_subnet.Public.id}"
  route_table_id = "${aws_route_table.rt.id}"
}

##############   NAT Gateway association for Private network  #######
resource "aws_route_table_association" "public" {
  subnet_id      = "${aws_subnet.Private.id}"
  route_table_id = "${aws_route_table.privatert.id}"
}
##############		Security Group	####################
resource "aws_security_group" "windowsVM" {
  name        = "windowsVM"
  description = "Enable RDP"
  vpc_id      = "${aws_vpc.VPC100.id}"

  ingress {
    # TLS (change to whatever ports you need)
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    # Please restrict your ingress to only necessary IPs and ports.
    # Opening to 0.0.0.0/0 can lead to security vulnerabilities.
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}


################  EIP 			###############


resource "aws_eip" "NAT-EIP" {
  vpc      = true
  tags = {
  Name = "NAT-EIP"
  }
}

#################   NAT Gateway    ###############

resource "aws_nat_gateway" "ngw" {
  allocation_id = "${aws_eip.NAT-EIP.id}"
  subnet_id     = "${aws_subnet.Public.id}"

  tags = {
    Name = "NATgwVPC100"
  }
}

##############		EC2 Public	####################

resource "aws_instance" "windows" {
  ami           = "ami-02666d31e797d5190"
  instance_type = "t2.micro"
  count = 1
  availability_zone = "us-east-1a"
  subnet_id= "${aws_subnet.Public.id}"
  vpc_security_group_ids = ["${aws_security_group.windowsVM.id}"]
  associate_public_ip_address = true
  key_name = "testlab"
  tags = {
    Name = "WS1"
  }
}

##############		EC2 Private	####################
resource "aws_instance" "windowsPrivate" {
  ami           = "ami-02666d31e797d5190"
  instance_type = "t2.micro"
  count = 1
  availability_zone = "us-east-1a"
  subnet_id= "${aws_subnet.Private.id}"
  vpc_security_group_ids = ["${aws_security_group.windowsVM.id}"]
  associate_public_ip_address = false
  key_name = "testlab"
  tags = {
    Name = "DB1"
  }
}

