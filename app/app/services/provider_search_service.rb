class ProviderSearchService
  PROVIDER_RESULT = Struct.new(:provider_name, :provider_options, :name, :logo_url, keyword_init: true)

  SUPPORTED_PROVIDERS = (ENV["SUPPORTED_PROVIDERS"] || "pinwheel")&.split(",")&.map(&:to_sym)

  def initialize(client_agency_id)
    client_agency_config = site_config[client_agency_id]

    @providers = SUPPORTED_PROVIDERS.map do |provider|
      case provider
      when :pinwheel
        PinwheelAdapter.new(client_agency_config.pinwheel_environment)
      when :argyle
        ArgyleAdapter.new(client_agency_config.argyle_environment)
      end
    end
  end

  def search(query = "")
    @providers.map { |provider| provider.query(query) }.flatten
  end

  private

  def site_config
    Rails.application.config.sites
  end

  class PinwheelAdapter
    def initialize(environment)
      @pinwheel = PinwheelService.new(environment)
    end

    def query(query)
      @pinwheel.fetch_items(q: query)["data"].map do |result|
        PROVIDER_RESULT.new(
          provider_name: :pinwheel,
          provider_options: {
            response_type: result["response_type"],
            provider_id: result["id"]
          },
          name: result["name"],
          logo_url: result["logo_url"]
        )
      end
    end
  end

  class ArgyleAdapter
    def initialize(environment)
      @argyle = ArgyleService.new(environment)
    end

    def query(query)
      @argyle.items(query)["results"].map do |result|
        PROVIDER_RESULT.new(
          provider_name: :argyle,
          provider_options: {
            response_type: result["kind"],
            provider_id: result["id"]
          },
          name: result["name"],
          logo_url: result["logo_url"]
        )
      end
    end
  end
end
