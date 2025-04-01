module ApiService
  extend ActiveSupport::Concern

  included do
    attr_reader :configuration

    # Add class methods to any class that includes this module
    class_object = self
    class << class_object
      def configure(config_mapping, default_config_key = nil)
        @configuration_mapping = config_mapping
        @default_config_key = default_config_key

        # Validate that the default config exists in the mapping
        if @default_config_key && !@configuration_mapping.key?(@default_config_key)
          raise ArgumentError, "Default configuration key '#{@default_config_key}' not found in configuration mapping"
        end

        @default_config_key
      end

      def get_configuration(config_key = nil)
        config_key_sym = config_key&.to_sym

        # First try the requested environment
        if config_key_sym && @configuration_mapping.key?(config_key_sym)
          @configuration = @configuration_mapping[config_key_sym].call
        end

        # If that fails, try the default environment
        if @default_config_key
          @configuration = @configuration_mapping[@default_config_key].call
        end

        if @configuration.nil?
          raise ArgumentError, "Could not find configuration for '#{config_key}'"
        end

        @configuration
      end
    end
  end

  def get_configuration(config_key = nil)
    self.class.get_configuration(config_key)
  end

  def build_url(endpoint)
    @http.build_url(endpoint).to_s
  end

  def make_request(method, endpoint, params = nil)
    response = case method
               when :get
                 @http.get(endpoint, params)
               when :post
                 @http.post(endpoint, params&.to_json)
               when :delete
                 @http.delete(endpoint)
               end

    response.body
  rescue Faraday::Error => e
    status = e.response&.dig(:status)
    body = e.response&.dig(:body)
    Rails.logger.error "Argyle API error: #{status} - #{body}"
    raise e
  rescue StandardError => e
    Rails.logger.error "Unexpected error in Argyle API request: #{e.message}"
  end
end
