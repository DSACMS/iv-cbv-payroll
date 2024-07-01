require "net/http"
require "uri"
require "json"

class NewRelicEventService
  EVENT_API_ENDPOINT = "https://insights-collector.newrelic.com/v1/accounts/"

  def self.track(event_type, attributes = {})
    new.send_event(event_type, attributes)
  end

  def send_event(event_type, attributes = {})
    payload = [
      {
        eventType: event_type,
        timestamp: Time.now.to_i,
        **attributes
      }
    ]

    uri = URI.parse("#{EVENT_API_ENDPOINT}#{account_id}/events")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri.request_uri)
    request["Content-Type"] = "application/json"
    request["X-Insert-Key"] = insert_key
    request.body = payload.to_json

    response = http.request(request)

    if response.code == "200"
      Rails.logger.info "New Relic event sent successfully: #{event_type}"
    else
      Rails.logger.error "Failed to send New Relic event: #{response.body}"
    end

    response
  rescue StandardError => e
    Rails.logger.error "Error sending New Relic event: #{e.message}"
  end

  private

  def account_id
    ENV["NEW_RELIC_ACCOUNT_ID"]
  end


  def insert_key
    ENV["NEWRELIC_KEY"]
  end
end
