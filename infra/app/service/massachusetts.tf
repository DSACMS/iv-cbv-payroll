# For the MA pilot, we will send files to an S3 bucket monitored by MA's MOVEIt
# system. For now, let's re-use the "storage" module.
module "storage_ma_moveit" {
  source = "../../modules/storage"
  name   = local.storage_config.massachusetts_moveit_bucket_name
}

# IAM user shared with MA DTA for purposes of pulling files
resource "aws_iam_user" "ma_moveit" {
  #checkov:skip=CKV_AWS_273:https://github.com/DSACMS/iv-cbv-payroll/pull/121#issuecomment-2261568434
  name = "ma-moveit-${var.environment_name}"
}

resource "aws_iam_user_policy_attachment" "ma_moveit" {
  user       = aws_iam_user.ma_moveit.name
  policy_arn = module.storage_ma_moveit.access_policy_arn
}

resource "aws_iam_access_key" "ma_moveit" {
  user = aws_iam_user.ma_moveit.name
}
