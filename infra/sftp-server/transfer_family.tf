
resource "aws_transfer_server" "this" {
    endpoint_type                     = "VPC"
    logging_role                      = resource.aws_iam_role.logging_role.arn
    identity_provider_type            = "AWS_LAMBDA"
    function                          = aws_lambda_function.sftp_auth_lambda_function.arn
    domain                            = "S3"
    sftp_authentication_methods       = "PASSWORD"
    protocols                         = ["SFTP"]
    structured_log_destinations       = ["${aws_cloudwatch_log_group.sftp.arn}:*"]
    endpoint_details {
        address_allocation_ids = aws_eip.static_sftp_ip[*].id
        vpc_id                 = aws_vpc.this.id
        subnet_ids             = aws_subnet.public[*].id
        security_group_ids     = [aws_security_group.sftp_sg.id]
    }    
}

resource "aws_cloudwatch_log_group" "sftp" {
  name_prefix = "sftp_"
}


resource "aws_iam_role_policy" "sftp_s3_policy" {
      name     = "sftp-s3-access-policy-${local.sftp_bucket_full_name}"
      role     = aws_iam_role.sftp_role.id
      policy = jsonencode({
          "Version": "2012-10-17",
          "Statement": [{
          "Sid": "ListBucketItems",
          "Effect": "Allow",
          "Action": [
              "s3:ListBucket",
              "s3:GetBucketLocation"
          ],
          "Resource": "arn:aws:s3:::${local.sftp_bucket_full_name}"
          },
          {
          "Sid": "BucketPermissions",
          "Effect": "Allow",
          "Action": [
              "s3:PutObject",
              "s3:GetObjectAcl",
              "s3:GetObject",
              "s3:DeleteObjectVersion",
              "s3:DeleteObject",
              "s3:PutObjectAcl",
              "s3:GetObjectVersion"
          ],
          "Resource": "arn:aws:s3:::${local.sftp_bucket_full_name}/*"
          }]
      })
  }

resource "aws_iam_role" "sftp_role" {
    name               = "sftp-transfer-s3-access-${local.sftp_bucket_full_name}"
    assume_role_policy = <<EOF
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": {
                    "Service": "transfer.amazonaws.com"
                },
                "Action": "sts:AssumeRole"
            }
        ]
    }
    EOF
}

