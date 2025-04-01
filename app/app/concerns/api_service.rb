module ApiService
  extend ActiveSupport::Concern

  included do
    attr_reader :environment

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

      def get_environment(env = nil)
        env_sym = env&.to_sym

        # First try the requested environment
        if env_sym && @configuration_mapping.key?(env_sym)
          return @configuration_mapping[env_sym].call
        end

        # If that fails, try the default environment
        if @default_config_key
          return @configuration_mapping[@default_config_key].call
        end

        raise ArgumentError, "Invalid environment: #{env}. No default environment configured."
      end
    end
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
