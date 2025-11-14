# Skip Shoryuken initialization in test environment
# Tests don't need actual SQS connectivity
return if Rails.env.test?

require "shoryuken"
require "aws-sdk-sqs"

# Log level configurable (defaults to INFO)
Shoryuken.logger.level = ENV.fetch("SHORYUKEN_LOG_LEVEL", "INFO").then { |l| Logger.const_get(l) rescue Logger::INFO }

region   = ENV.fetch("AWS_REGION", "us-east-1")
endpoint = ENV["AWS_SQS_ENDPOINT"] # <-- set ONLY in local dev (Moto/LocalStack). Unset in ECS.

if endpoint && !endpoint.empty?
  # Local dev: explicit dummy credentials + custom endpoint
  Shoryuken.sqs_client = Aws::SQS::Client.new(
    region: region,
    endpoint: endpoint,
    credentials: Aws::Credentials.new(
      ENV.fetch("AWS_ACCESS_KEY_ID", "test"),
      ENV.fetch("AWS_SECRET_ACCESS_KEY", "test")
    )
  )

  Shoryuken.sqs_client_receive_message_opts = {
    wait_time_seconds: ENV.fetch("SHORYUKEN_WAIT_SECONDS_LOCAL", "1").to_i, # snappy dev cycle
    max_number_of_messages: ENV.fetch("SHORYUKEN_MAX_MESSAGES", "10").to_i
  }
else
  # ECS/real AWS: use default credential chain (task role), no endpoint
  Shoryuken.sqs_client = Aws::SQS::Client.new(region: region)

  Shoryuken.sqs_client_receive_message_opts = {
    wait_time_seconds: ENV.fetch("SHORYUKEN_WAIT_SECONDS", "20").to_i, # long polling in prod
    max_number_of_messages: ENV.fetch("SHORYUKEN_MAX_MESSAGES", "10").to_i
  }
end
