# Load the Rails application.
require_relative "application"


# Initialize the Rails application.
Rails.application.initialize!

Rails.application.config.after_initialize do
  # Your code here
  # You can call services, start background tasks, preload data, etc.
  # if the password is not defined, Mission Control will 401
  # TODO once we're on rails credentials, remove this and replace with rails creds
  MissionControl::Jobs.http_basic_auth_user = ENV["MISSION_CONTROL_USER"]
  MissionControl::Jobs.http_basic_auth_password = ENV["MISSION_CONTROL_PASSWORD"]
end
