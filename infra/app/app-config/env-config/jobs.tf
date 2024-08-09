locals {
  # Configuration for default jobs to run in every environment.
  # See description of `file_upload_jobs` variable in the service module (infra/modules/service/variables.tf)
  # for the structure of this configuration object.
  # One difference is that `source_bucket` is optional here. If `source_bucket` is not
  # specified, then the source bucket will be set to the storage bucket's name
  file_upload_jobs = {
    # Example job configuration
    # etl = {
    #   path_prefix  = "etl/input",
    #   task_command = ["python", "-m", "flask", "--app", "app.py", "etl", "<object_key>"]
    # }
  }

  # Configuration for cron jobs to run in every environment.

  # The `schedule_expression` supports cron format (min, hour, day_of_month,
  # month, day_of_week, year) and runs in the `America/New_York` time zone.
  #
  # See description of `cron_jobs` variable in the service module (infra/modules/service/variables.tf)
  cron_jobs = {
    # TODO: Uncomment when https://github.com/DSACMS/iv-cbv-payroll/pull/155 is merged.
    # redact_data = {
    #   schedule_expression = "cron(0 * * * ? *)"
    #   task_command        = ["bin/rails", "data_deletion:redact_all"]
    # }
  }
}
