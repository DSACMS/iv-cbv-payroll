class ProviderSearchService
  PROVIDER_RESULT = Struct.new(:provider_name, :provider_options, :name, :logo_url, keyword_init: true)

  def initialize(client_agency_id)
    set_pinwheel(client_agency_id)
    set_argyle(client_agency_id)
  end

  def search(query = "")
    [
      *@argyle.items(query)["results"].map do |result|
        PROVIDER_RESULT.new(provider_name: :argyle, provider_options: { response_type: result["kind"], provider_id: result["id"] }, name: result["name"], logo_url: result["logo_url"])
      end,
      *@pinwheel.fetch_items(q: query)["data"].map do |result|
        PROVIDER_RESULT.new(provider_name: :pinwheel, provider_options: { response_type: result["response_type"], provider_id: result["id"] }, name: result["name"], logo_url: result["logo_url"])
      end
    ]
  end

  private

  def site_config
    Rails.application.config.sites
  end

  def set_pinwheel(client_agency_id)
    environment = site_config[client_agency_id].pinwheel_environment
    @pinwheel ||= PinwheelService.new(environment)
  end

  def set_argyle(client_agency_id)
    environment = site_config[client_agency_id].argyle_environment
    @argyle ||= ArgyleService.new(environment)
  end
end
