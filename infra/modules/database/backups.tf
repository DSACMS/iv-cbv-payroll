# Database Backups
# ----------------

# Backup plan that defines when and how to backup and which backup vault to store backups in
# See https://docs.aws.amazon.com/aws-backup/latest/devguide/about-backup-plans.html
resource "aws_backup_plan" "backup_plan" {
  count = var.enable_aws_backup ? 1 : 0

  name = "${var.name}-db-backup-plan"

  rule {
    rule_name         = "${var.name}-db-backup-rule"
    target_vault_name = aws_backup_vault.backup_vault[0].name
    schedule          = "cron(0 7 * * ? *)" # Run daily at 7am UTC (2am EST)

    lifecycle {
      delete_after = 14
    }
  }
}

# Backup vault that stores and organizes backups
# See https://docs.aws.amazon.com/aws-backup/latest/devguide/vaults.html
resource "aws_backup_vault" "backup_vault" {
  count = var.enable_aws_backup ? 1 : 0

  name        = "${var.name}-db-backup-vault"
  kms_key_arn = data.aws_kms_key.backup_vault_key.arn

  # Use a separate line to support automated terraform destroy commands
  force_destroy = var.is_temporary
}

# KMS Key for the vault
# This key was created by AWS by default alongside the vault
data "aws_kms_key" "backup_vault_key" {
  key_id = "alias/aws/backup"
}

# Backup selection defines which resources to backup
# See https://docs.aws.amazon.com/aws-backup/latest/devguide/assigning-resources.html
# and https://docs.aws.amazon.com/aws-backup/latest/devguide/API_BackupSelection.html
resource "aws_backup_selection" "db_backup" {
  count = var.enable_aws_backup ? 1 : 0

  name         = "${var.name}-db-backup"
  plan_id      = aws_backup_plan.backup_plan[0].id
  iam_role_arn = aws_iam_role.db_backup_role[0].arn

  resources = [
    aws_rds_cluster.db.arn
  ]
}

# Role that AWS Backup uses to authenticate when backing up the target resource
resource "aws_iam_role" "db_backup_role" {
  count = var.enable_aws_backup ? 1 : 0

  name_prefix        = "${var.name}-db-backup-"
  assume_role_policy = data.aws_iam_policy_document.db_backup_policy.json
}

data "aws_iam_policy_document" "db_backup_policy" {
  statement {
    actions = [
      "sts:AssumeRole",
    ]

    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "db_backup_role_policy_attachment" {
  count = var.enable_aws_backup ? 1 : 0

  role       = aws_iam_role.db_backup_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}
