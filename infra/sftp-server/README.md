# managed-secure-sftp-using-terraform
Forked from: https://github.com/RDarrylR/managed-secure-sftp-using-terraform. This repository is associated with the following blog https://darryl-ruggles.cloud/managed-secure-sftp-using-terraform
Original source code has no associated license definition.

### Purpose
The purpose of this terraform module is to setup a quick SFTP user to assist in end to end testing SFTP connections.  

This stack deploys an S3 Bucket backed SFTP server (Based on the **AWS Transfer Family** service) in AWS using static IP addresses that will restrict incoming connections to specific IP ranges. Authentication is password based using AWS Lambda for validation with passwords stored in AWS Secrets Manager. **Please see the note below in the Cleanup section that setting up this SFTP server will cost you real money - there is no free tier!!**

### Usage
* THIS SHOULD ONLY BE RUN IN DEMO AWS ENVIRONMENT.
* This should only be temporarily provisioned and destroyed as it costs $7/day and opens an SSH port on 22.

### Key Folders

- `./infra/sftp-server` - Contains all the files in the Terraform stack to deploy everything in the backend including the AWS Lambda Function, S3 Buckets, Secrets Manager secrets, AWS Transfer Family SFTP server, and more.
- `./infra/sftp-server/functions` - Source code for the Python function used to authenticate user login to the SFTP server
- `./infra/sftp-server/policies` - AWS Auth policy for lambda functions

### Requirements

-   Terraform CLI (https://developer.hashicorp.com/terraform/install)

### Deploy the project

To deploy the project, you need to do the following:

1. Clone the repo
2. Go to the terraform directory
3. Make changes to the `configuration.tf` file to setup which incoming IP CIDR ranges should be allowed access to the server, the sftp user name, which AWS region to use, and other values.
4. Run `terraform init`
5. run `terraform apply` (and type "yes" when it's done with the plan)
6. Note the output from the terraform apply. It will contain the static IP addresses where the SFTP server is running and the S3 bucket which will contain all the files uploaded/downloadable for the sftp server.
7. Test with a local SFTP client (e.g. FileZilla or sftp cli)
   - Host: <the IP address output by `terraform apply`>
   - Username: sftpuser
   - Password: found via parameter store at `/sftp-server/sftp_test_user_password` 
   - Directory: /TEST 

### Cleanup

# **WARNING: If you leave the SFTP server running and do not destroy it with Terraform then you will incur real costs in $$$s. AWS Transfer Family SFTP servers cost 7 USD per day (plus bandwidth charges)!!!**


Run the following terraform command to destroy all the infrastructure.

```bash
terraform destroy (from the infra directory)
```

### Read More


