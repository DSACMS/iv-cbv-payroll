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

    send_newrelic_queue_metrics = {
      task_command        = ["bin/rails", "telemetry:send_queue_metrics"]
      schedule_expression = "cron(* * ? * * *)" # every minute
    }

    send_az_reports = {
      task_command        = ["bin/rails", "az_des:deliver_csv_reports"]
      schedule_expression = "cron(0 15 ? * * *)" # Every day at 3pm UTC (8am MST / 10am EST / 9am EDT)
    }

    redact_data = {
      task_command        = ["bin/rails", "data_deletion:redact_all"]
      schedule_expression = "cron(0 14 ? * * *)" # Every day at 2pm UTC (9am EST / 10am EDT)
    }

    clear_old_background_jobs = {
      task_command = ["bin/rails", "data_deletion:clear_old_background_jobs"]
      schedule_expression = "cron(*/12 * * * * *)" # once every 12 minutes
    }
  }
}
