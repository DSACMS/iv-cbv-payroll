require "shoryuken"
require "aws-sdk-sqs"

Shoryuken.logger.level = Logger::INFO

Shoryuken.sqs_client = Aws::SQS::Client.new(
  endpoint: ENV.fetch("SQS_ENDPOINT", "http://localhost:5000"),
  region:   ENV.fetch("AWS_REGION", "us-east-1"),
  credentials: Aws::Credentials.new(
    ENV.fetch("AWS_ACCESS_KEY_ID", "test"),
    ENV.fetch("AWS_SECRET_ACCESS_KEY", "test")
  )
)

# Optional: shorter waits in local dev
Shoryuken.sqs_client_receive_message_opts = {
  wait_time_seconds: 1, # Moto supports long polling, keep it low for dev
  max_number_of_messages: 10
}
