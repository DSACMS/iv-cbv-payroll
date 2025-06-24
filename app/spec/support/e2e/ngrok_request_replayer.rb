module E2e
  class NgrokRequestReplayer
    # `replacements` is a hash whose keys are the replacement, and the value is
    # a proc that defines the value to replace. The proc is called with the saved request.
    #
    # This matches the paradigm used by VCR's `filter_sensitive_data`
    # configuration option.
    #
    # For example:
    #
    # NgrokRequestReplayer.new(replacements: {
    #   "<PINWHEEL_WEBHOOK_SIGNATURE>": ->(request) do
    #     # calculate the webhook signature with the request
    #   end
    # })
    #
    def initialize(replacements: {}, ngrok_url: "http://localhost:4040", logger: Rails.logger)
      @replacements = replacements
      @url = URI(ngrok_url)
      @logger = logger.tagged("WEBHOOKS")
    end

    # Pull a list of webhooks from Ngrok's local API, and return an object
    # suitable for replaying.
    def list_requests
      ngrok_response = Net::HTTP.get(URI.join(@url, "/api/requests/http"))
      parsed = JSON.parse(ngrok_response)["requests"].reverse

      parsed.map do |item|
        # Parse the raw HTTP Request body from Ngrok's "raw" serialized value.
        #
        # Why? Although Ngrok's API does return a parsed version of the HTTP
        # Request, it doesn't include the POST body contents, so we need to
        # parse the HTTP request ourselves here.
        #
        # The body follows a blank line (two consecutive \r\n linebreaks.)
        _headers, body = Base64.decode64(item["request"]["raw"]).split("\r\n\r\n", 2)

        apply_replacements(
          uri: item["request"]["uri"],
          method: item["request"]["method"],
          headers: item["request"]["headers"],
          body: body
        )
      end
    end

    def replay_requests(recorded_requests, server_url)
      Net::HTTP.start(server_url.host, server_url.port) do |http|
        recorded_requests.each do |recorded_request|
          @logger.info "Replaying request for #{recorded_request[:method]} #{recorded_request[:uri]}"
          recorded_request = reverse_replacements(recorded_request)

          replay_request = Net::HTTP.const_get(recorded_request[:method].capitalize).new(recorded_request[:uri])
          recorded_request[:headers].each do |key, value|
            replay_request[key] = value
          end

          replay_response = http.request(replay_request, recorded_request[:body])
          if replay_response.code.to_i >= 400
            @logger.warn "Warning: Got status #{replay_response.code} from webhook. Body: #{replay_response.body}"
          end
        end
      end
    end

    private

    def apply_replacements(request_hash)
      replacements_to_make = @replacements.transform_values { |r| r.call(request_hash) }.invert

      replace_all(request_hash[:headers], replacements_to_make)

      request_hash
    end

    def reverse_replacements(request_hash)
      replacements_to_make = @replacements.transform_values { |r| r.call(request_hash) }

      replace_all(request_hash[:headers], replacements_to_make)

      request_hash
    end

    def replace_all(object, replacements_to_make)
      case object
      when String
        replacements_to_make.each { |original, replacement| object.gsub!(original, replacement) }
      when Array
        object.map { |i| replace_all(i, replacements_to_make) }
      when Hash
        object.map { |k, v| [ k, replace_all(v, replacements_to_make) ] }.to_h
      end
    end
  end
end
