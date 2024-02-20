# Create a VPC
resource "aws_vpc" "mtc_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "dev_vpc"
  }
}

resource "aws_subnet" "mtc_public_subnet" {
  cidr_block              = "10.0.1.0/24"
  vpc_id                  = aws_vpc.mtc_vpc.id
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "dev_public"
  }
}

resource "aws_internet_gateway" "mtc_gw" {
  vpc_id = aws_vpc.mtc_vpc.id

  tags = {
    Name = "dev_igw"
  }
}

resource "aws_route_table" "mtc_rt" {
  vpc_id = aws_vpc.mtc_vpc.id

  tags = {
    Name = "dev_rt"
  }
}

resource "aws_route" "mtc_r" {
  route_table_id         = aws_route_table.mtc_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.mtc_gw.id
}

resource "aws_route_table_association" "mtc_a" {
  subnet_id      = aws_subnet.mtc_public_subnet.id
  route_table_id = aws_route_table.mtc_rt.id
}

resource "aws_security_group" "mtc_allow_tls" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.mtc_vpc.id

  tags = {
    Name = "allow_tls"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_tls_ipv4" {
  security_group_id = aws_security_group.mtc_allow_tls.id
  # cidr_ipv4         = aws_vpc.mtc_vpc.cidr_block
  cidr_ipv4 = "0.0.0.0/0"
  # from_port   = 0
  ip_protocol = "-1"
  #to_port     = 0
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.mtc_allow_tls.id
  cidr_ipv4         = "0.0.0.0/0"
  #cidr_blocks = ["0.0.0.0/0"]

  ip_protocol = "-1" # semantically equivalent to all ports
}

resource "aws_key_pair" "mtc_auth" {
  key_name   = "mtc-key"
  public_key = file("~/.ssh/mtckey.pub")
}

resource "aws_instance" "mtc_ec2" {
  ami                    = data.aws_ami.mtc_server.id
  instance_type          = "t3.micro"
  key_name               = aws_key_pair.mtc_auth.id
  vpc_security_group_ids = [aws_security_group.mtc_allow_tls.id]
  subnet_id              = aws_subnet.mtc_public_subnet.id
  user_data              = file("userdata.tpl")

  tags = {
    Name = "dev_ec2"
  }

  provisioner "local-exec" {
    command = templatefile("${var.host_os}-ssh-config.tpl", {
        hostname = self.public_ip,
        user = "ubuntu",
        identityfile = "~/.ssh/mtckey"
    })
    interpreter = var.host_os == "windows" ? ["Powershell", "-Command"] : ["bash", "-c"]
  }
}

