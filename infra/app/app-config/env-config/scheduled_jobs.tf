locals {
  # The `task_command` is what you want your scheduled job to run, for example: ["poetry", "run", "flask"].
  # Schedule expression defines the frequency at which the job should run.
  # The syntax for `schedule_expression` is explained in the following documentation:
  # https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-scheduled-rule-pattern.html
  scheduled_jobs = {
    # send weekly reports to all configured partners
    send_weekly_reports = {
      task_command        = ["bin/rails", "weekly_reports:send_all"]
      schedule_expression = "cron(0 12 ? * MON *)" # Every Monday at 12pm UTC (7am EST / 8am EDT)
    }

    # AZ daily summary report
    send_az_reports = {
      task_command        = ["bin/rails", "az_des:deliver_csv_reports"]
      schedule_expression = "cron(0 15 ? * * *)" # Every day at 3pm UTC (8am MST / 10am EST / 9am EDT)
    }

    # PA daily summary reports
    send_pa_reports = {
      task_command        = ["bin/rails", "pa_dhs:deliver_csv_reports"]
      schedule_expression = "cron(0 15 ? * * *)" # Every day at 3pm UTC (8am MST / 10am EST / 9am EDT)
    }

    # Follow data retention policy to redact data every day
    redact_data = {
      task_command        = ["bin/rails", "data_deletion:redact_all"]
      schedule_expression = "cron(0 10 ? * * *)" # Every day at 10am UTC (5am EST / 6am EDT)
    }
  }
}
