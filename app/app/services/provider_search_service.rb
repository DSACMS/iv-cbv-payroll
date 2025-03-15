class ProviderSearchService
  SUPPORTED_PROVIDERS = (ENV["SUPPORTED_PROVIDERS"] || "pinwheel")&.split(",")&.map(&:to_sym)

  def initialize(client_agency_id)
    @client_agency_config = site_config[client_agency_id]
  end

  def search(query = "")
    SUPPORTED_PROVIDERS.map do |provider|
      case provider
      when :pinwheel
        Aggregators::Sdk::PinwheelService.new(@client_agency_config.pinwheel_environment).fetch_items(q: query)["data"].map do |result|
          Aggregators::ResponseObjects::SearchResult.from_pinwheel(result)
        end
      when :argyle
        Aggregators::Sdk::ArgyleService.new(@client_agency_config.argyle_environment).items(query)["results"].map do |result|
          Aggregators::ResponseObjects::SearchResult.from_argyle(result)
        end
      end
    end.flatten
  end

  private

  def site_config
    Rails.application.config.client_agencies
  end
end
