
resource "aws_vpc" "this" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "sftp-vpc"
  }
  # checkov:skip=CKV2_AWS_12: since this is temporary sftp server, allow traffic to the VPC.
}

resource "aws_flow_log" "flow_log" {
  iam_role_arn    = aws_iam_role.log_stream_iam_role.arn
  log_destination = aws_cloudwatch_log_group.cloudwatch_log_group.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.this.id
}

resource "aws_kms_key" "sftp_vpc_logs_kms_key" {
  description             = "Customer Managed KMS key to encrypt SSM parameters for test SFTP server."
  deletion_window_in_days = 10
  enable_key_rotation     = true # Enable automatic key rotation
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "EnableIAMUserPermissions",
        Effect    = "Allow",
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" },
        Action    = "kms:*",
        Resource  = "*"
      },
      {
        Sid       = "AllowCloudWatchLogsUseOfTheKey",
        Effect    = "Allow",
        Principal = { Service = "logs.${var.aws_region}.amazonaws.com" },
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        Resource = "*",
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" : "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:*"
          }
        }
      }
    ]
  })
}
resource "aws_cloudwatch_log_group" "cloudwatch_log_group" {
  name              = "sftp-server-logs"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.sftp_vpc_logs_kms_key.arn
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "sftp-igw"
  }
}

resource "aws_subnet" "public" {
  #checkov:skip=CKV_AWS_130: Ensure VPC subnets do not assign public IP by default - This is a temporary service.
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
  #checkov:skip=CKV2_AWS_19: EIP is attached to TransferFamily not EC2
  count = length(var.az_list)
  tags = {
    Name = "sftp-static-ip-${count.index}"
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
  vpc_id      = aws_vpc.this.id
  description = "Security Group for SFTP Test Server"

  #checkov:skip=CKV_AWS_24: Ensure no security groups allow ingress from 0.0.0.0:0 to port 22. - This is limited SFTP server.
  ingress {
    description = "SFTP service port"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_incoming_cidr_list # Only allow incoming from fixed IP
  }

  tags = {
    Name = "sftp-sg"
  }
}

resource "aws_iam_role" "log_stream_iam_role" {
  name               = "sftp-server-logstream-role"
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "vpc-flow-logs.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

data "aws_iam_policy_document" "log_stream_iam_policy_doc" {
  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
    ]

    resources = [
      aws_cloudwatch_log_group.cloudwatch_log_group.arn,
      "${aws_cloudwatch_log_group.cloudwatch_log_group.arn}:*"
    ]


  }
}

resource "aws_iam_role_policy" "log_stream_iam_policy" {
  name   = "sftp-log-stream-iam-role-policy"
  role   = aws_iam_role.log_stream_iam_role.id
  policy = data.aws_iam_policy_document.log_stream_iam_policy_doc.json
}