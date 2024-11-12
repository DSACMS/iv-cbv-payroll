locals {
  # The `task_command` is what you want your scheduled job to run, for example: ["poetry", "run", "flask"].
  # Schedule expression defines the frequency at which the job should run.
  # The syntax for `schedule_expression` is explained in the following documentation:
  # https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-scheduled-rule-pattern.html
  scheduled_jobs = {
    send_weekly_reports = {
      task_command        = ["bin/rails", "weekly_reports:send_all"]
      schedule_expression = "cron(0 12 ? * MON *)" # Every Monday at 12pm UTC (7am EST / 8am EDT)
    }

    redact_data = {
      task_command        = ["bin/rails", "data_deletion:redact_all"]
      schedule_expression = "cron(0 14 ? * * *)" # Every day at 2pm UTC (9am EST / 10am EDT)
    }

    send_invitation_reminders = {
      task_command        = ["bin/rails", "invitation_reminders:send_all"]
      schedule_expression = "cron(0 14 ? * * *)" # Every day at 2pm UTC (9am EST / 10am EDT)
    }
  }
}
