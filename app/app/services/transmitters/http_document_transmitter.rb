require "tmpdir"

class Transmitters::HttpDocumentTransmitter
  TRANSMISSION_METHOD = "http"

  def initialize(activity_flow, current_agency)
    @activity_flow = activity_flow
    @current_agency = current_agency
    @processed_s3_service = ProcessedDownloadService.new
  end

  def deliver
    documents = ActivityDocumentsService.new(@activity_flow).all

    Dir.mktmpdir("activity-flow-http-transmission-") do |directory|
      documents.each do |document|
        file_path = File.join(directory, document.file_name)
        @processed_s3_service.download_file(document.attachment.blob.key, file_path)
        deliver_document(document, File.binread(file_path))
      end
    end

    Rails.logger.info(
      "Activity flow HTTP transmission flow_id=#{@activity_flow.id} " \
      "confirmation_code=#{@activity_flow.confirmation_code} " \
      "document_count=#{documents.size}"
    )
  end

  private

  def deliver_document(document, content)
    url = destination_url!
    request = Net::HTTP::Post.new(url)
    request.content_type = document.attachment.blob.content_type.presence || "application/octet-stream"
    request.content_length = content.bytesize
    request.body = content
    request["Content-Disposition"] = %(attachment; filename="#{document.file_name}")
    request["X-IVAAS-Timestamp"] = timestamp
    request["X-IVAAS-Signature"] = signature(content)
    request["X-IVAAS-Confirmation-Code"] = @activity_flow.confirmation_code

    custom_headers.each { |header_name, header_value| request[header_name] = header_value }

    Rails.logger.info "Sending activity document transmission to #{url}: filename=#{document.file_name}"
    request_started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    response = Net::HTTP.start(url.hostname, url.port, use_ssl: url.scheme == "https") do |http|
      http.request(request)
    end
    request_duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - request_started_at
    Rails.logger.info(
      "Activity document transmission response from #{url}: status=#{response.code} " \
      "duration=#{format("%.3f", request_duration)}s filename=#{document.file_name}"
    )

    return if response.is_a?(Net::HTTPSuccess)

    raise_response_error!(response)
  end

  def destination_url!
    url = @current_agency.transmission_method_configuration["documents_api_url"]
    unless url.present?
      raise ArgumentError, "Invalid documents_api_url #{url.inspect}: must be an absolute HTTP(S) URL"
    end

    uri = URI.parse(url)
    return uri if uri.is_a?(URI::HTTP) && uri.host.present?

    raise ArgumentError, "Invalid documents_api_url #{url.inspect}: must be an absolute HTTP(S) URL"
  rescue URI::InvalidURIError
    raise ArgumentError, "Invalid documents_api_url #{url.inspect}: must be an absolute HTTP(S) URL"
  end

  def custom_headers
    @current_agency.transmission_method_configuration["custom_headers"] || {}
  end

  def timestamp
    @timestamp ||= Time.now.to_i
  end

  def signature(content)
    JsonApiSignature.generate(content, timestamp, api_key_for_agency!)
  end

  def api_key_for_agency!
    @api_key ||= User.api_key_for_agency(@current_agency.id)
    return @api_key if @api_key

    Rails.logger.error "No active API key found for agency #{@current_agency.id}"
    raise "No active API key found for agency #{@current_agency.id}"
  end

  def raise_response_error!(response)
    message = "Unexpected response from agency: code=#{response.code} message=#{response.message}"
    Rails.logger.error message
    Rails.logger.error "Error response body: #{response.body}"

    error_class = silently_retry_error_codes.include?(response.code.to_s) ?
      ApplicationJob::SilencedError :
      HttpDocumentTransmitterError
    raise error_class, message
  end

  def silently_retry_error_codes
    Array(@current_agency.transmission_method_configuration["silently_retry_error_codes"]).map(&:to_s)
  end

  class HttpDocumentTransmitterError < StandardError; end
end
