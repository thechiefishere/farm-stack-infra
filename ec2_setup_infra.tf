resource "aws_vpc" "john_vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "john_vpc",
    createdby = "john.toriola@cecureintel.com"
  }
}

resource "aws_internet_gateway" "john_igw" {
  vpc_id = aws_vpc.john_vpc.id

  tags = {
    Name = "john_igw"
  }
}

resource "aws_subnet" "john_public_subnet" {
  vpc_id                  = aws_vpc.john_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "john_public_subnet"
  }
}

resource "aws_route_table" "john_public_route_table" {
  vpc_id = aws_vpc.john_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.john_igw.id
  }

  tags = {
    Name = "john_public_route_table"
  }
}

resource "aws_route_table_association" "john_route_table_association" {
  subnet_id      = aws_subnet.john_public_subnet.id
  route_table_id = aws_route_table.john_public_route_table.id
}

resource "aws_security_group" "john_frontend_sg" {
  name        = "john_frontend_sg"
  description = "frontend security group"
  vpc_id      = aws_vpc.john_vpc.id

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

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "john_backend_sg" {
  name        = "john_backend_sg"
  description = "Backend server sg"
  vpc_id      = aws_vpc.john_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "john_backend_server" {
  ami                    = "ami-020cba7c55df1f615"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.john_public_subnet.id
  vpc_security_group_ids = [aws_security_group.john_backend_sg.id]
  key_name               = "jbaba-key"

  user_data = <<EOF
#!/bin/bash
set -e

# Update package list
apt-get update -y

# Install Python
apt-get install -y python3 python3-pip python3-venv

# Install MongoDB
apt-get install -y gnupg curl
curl -fsSL https://pgp.mongodb.com/server-6.0.asc | gpg -o /usr/share/keyrings/mongodb-server-6.0.gpg --dearmor
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-6.0.gpg ] https://repo.mongodb.org/apt/ubuntu $(lsb_release -sc)/mongodb-org/6.0 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-6.0.list
apt-get update -y
apt-get install -y mongodb-org

# Start MongoDB service
systemctl start mongod
systemctl enable mongod

# Wait for MongoDB to fully start
sleep 5

# Create MongoDB admin user
mongosh <<EOM
use admin
db.createUser({
  user: "username",
  pwd: "password",
  roles: [{ role: "root", db: "admin" }]
})
EOM

# Create application database
mongosh <<EOM
use dbname
db.createCollection("test")
EOM

EOF

  tags = {
    Name      = "john_backend_server"
    createdby = "john.toriola@cecureintel.com"
  }
}


resource "aws_instance" "john_frontend_server" {
  ami                    = "ami-020cba7c55df1f615"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.john_public_subnet.id
  vpc_security_group_ids = [aws_security_group.john_frontend_sg.id]
  key_name = "jbaba-key"

  user_data = <<EOF
#!/bin/bash
# Update package list and install Nginx
apt-get update
apt-get install -y nginx
# Start Nginx and enable it on boot
systemctl start nginx
systemctl enable nginx
# Ensure /var/www/html exists and has correct permissions
mkdir -p /var/www/html
chown -R www-data:www-data /var/www/html
EOF

  tags = {
    Name = "john_frontend_server",
    createdby = "john.toriola@cecureintel.com"
  }
}