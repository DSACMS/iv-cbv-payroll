class ProviderSearchService
  SUPPORTED_PROVIDERS = (ENV["SUPPORTED_PROVIDERS"] || "pinwheel")&.split(",")&.map(&:to_sym)

  # item_000136007 - SSA
  # item_000042186 - Veterans Affairs
  # item_000023897 - Louisiana Workforce Commission, which administers Unemployment Insurance
  BLOCKED_ARGYLE_EMPLOYERS = %w[item_000136007 item_000042186 item_000023897]

  # 0bab321e-64ea-4047-8d8a-44ba283f6cd8 - Social Security Administration - Retirement, Survivors, Disability benefits
  # 3f7b6ce9-6371-4bb8-8c2f-051c446dc55c - Veterans Affairs benefits
  BLOCKED_PINWHEEL_EMPLOYERS = %w[0bab321e-64ea-4047-8d8a-44ba283f6cd8 3f7b6ce9-6371-4bb8-8c2f-051c446dc55c]

  def initialize(client_agency_id, providers: SUPPORTED_PROVIDERS)
    @client_agency_config = site_config[client_agency_id]
    @providers = providers
  end

  def search(query = "")
    results = []

    if @providers.include?(:argyle)
      argyle_service = Aggregators::Sdk::ArgyleService.new(@client_agency_config.argyle_environment)

      results = argyle_service.employer_search(query)["results"].map do |result|
        Aggregators::ResponseObjects::SearchResult.from_argyle(result)
      end

      results = filter_results(results, BLOCKED_ARGYLE_EMPLOYERS)
    end

    if @providers.include?(:pinwheel) && (results.length == 0 || !any_exact_matches?(results, query))
      pinwheel_service = Aggregators::Sdk::PinwheelService.new(@client_agency_config.pinwheel_environment)

      pinwheel_results = pinwheel_service.fetch_items(q: query, supported_jobs: %w[paystubs])["data"].map do |result|
        Aggregators::ResponseObjects::SearchResult.from_pinwheel(result)
      end

      # Use Pinwheel's results if there aren't any results from Argyle, or
      # there is an exact match from Pinwheel.
      results = pinwheel_results if results.length == 0 || any_exact_matches?(pinwheel_results, query)

      results = filter_results(results, BLOCKED_PINWHEEL_EMPLOYERS)
    end

    results
  end

  def filter_results(results, blocked_employers)
    results.select { |result| !result.provider_options.provider_id.in? blocked_employers }
  end

  # TODO: this data should be loading from a config file instead of from hardcoded arrays within this file - see FFS-2661
  def top_aggregator_options(type)
    case type
    when "payroll"
      Aggregators::ResponseObjects::SearchResult.from_aggregator_options(TOP_PROVIDERS, @providers)
    when "employer"
      Aggregators::ResponseObjects::SearchResult.from_aggregator_options(TOP_EMPLOYERS, @providers)
    end
  end

  private

  def site_config
    Rails.application.config.client_agencies
  end

  def any_exact_matches?(results, original_query)
    results.any? { |result| normalize_name(result.name) == normalize_name(original_query) }
  end

  def normalize_name(name)
    # "Wal-Mart, LLC" => "walmartllc"
    name.downcase.gsub(/[^0-9a-z]+/, "")
  end

  # TODO: move these to a config file - see FFS-2661
  TOP_PROVIDERS = [
    {
      name: "ADP",
      response_type: "platform",
      logo_url: "https://cdn.getpinwheel.com/assets/platforms/logos/search/adpPortal.svg",
      provider_ids: {
        pinwheel: "5becff90-1e35-450a-8995-13ac411e749b",
        argyle: "item_000026933"
      }
    },
    {
      name: "Workday",
      response_type: "platform",
      logo_url: "https://cdn.getpinwheel.com/assets/platforms/logos/search/cfmpw.png",
      provider_ids: {
        pinwheel: "5965580e-380f-4b86-8a8a-7278c77f73cb",
        argyle: "item_000043816"
      }
    },
    {
      name: "Paycom",
      response_type: "platform",
      logo_url: "https://cdn.getpinwheel.com/assets/platforms/logos/search/paycom.svg",
      provider_ids: {
        pinwheel: "3f812c04-ac83-495b-99ca-7ec7d56dc68b",
        argyle: "item_000029935"
      }
    },
    {
      name: "Paychex",
      response_type: "platform",
      logo_url: "https://cdn.getpinwheel.com/assets/platforms/logos/search/paychex.svg",
      provider_ids: {
        pinwheel: "9a4e213b-aeed-4cb2-aace-696bcd2b1e0d",
        argyle: "item_000029932"
      }
    },
    {
      name: "Paylocity",
      response_type: "platform",
      logo_url: "https://cdn.getpinwheel.com/assets/platforms/logos/search/paylocity.png",
      provider_ids: {
        pinwheel: "913170d1-393c-4f35-8c23-df3133ce7529",
        argyle: "item_000029947"
      }
    },
    {
      name: "Paycor",
      response_type: "platform",
      logo_url: "https://cdn.getpinwheel.com/assets/platforms/logos/search/paycor.png",
      provider_ids: {
        pinwheel: "b0b655f8-4ae6-4d09-a60f-1df9a2a1fd16",
        argyle: "item_000029936"
      }
    }
  ]
  TOP_EMPLOYERS = [
    {
      name: "Amazon",
      response_type: "employer",
      logo_url: "https://cdn.getpinwheel.com/assets/employers/logos/Amazon.svg",
      provider_ids: {
        pinwheel: "d66e65b2-536d-4b2d-b73c-f6addd66c0f4",
        argyle: "item_000248659"
      }
    },
    {
      name: "DoorDash",
      response_type: "employer",
      logo_url: "https://cdn.getpinwheel.com/assets/employers/logos/DoorDash%20%28Dasher%29.svg",
      provider_ids: {
        pinwheel: "737d833a-1b68-44f7-92ae-3808374cb459",
        argyle: "item_000012375"
      }
    },
    {
      name: "Uber Driver",
      response_type: "employer",
      logo_url: "https://cdn.getpinwheel.com/assets/employers/logos/Uber%20%28Driver%29.svg",
      provider_ids: {
        pinwheel: "91063607-2b4a-4c8e-8045-a543f01b8b09",
        argyle: "item_000041078"
      }
    },
    {
      name: "Lyft Driver",
      response_type: "employer",
      logo_url: "https://cdn.getpinwheel.com/assets/employers/logos/Lyft%20%28Driver%29.svg",
      provider_ids: {
        pinwheel: "70b2bed2-ada8-49ec-99c2-691cc7d28df6",
        argyle: "item_000024123"
      }
    },
    {
      name: "Instacart",
      response_type: "employer",
      logo_url: "https://cdn.getpinwheel.com/assets/employers/logos/Instacart%20%28Full%20Service%20Shopper%29.svg",
      provider_ids: {
        pinwheel: "9f7ddcaf-cbc5-4bd2-b701-d40c67389eae",
        argyle: "item_000020392"
      }
    },
    {
      name: "TaskRabbit",
      response_type: "employer",
      logo_url: "https://cdn.getpinwheel.com/assets/platforms/logos/search/taskRabbit.png",
      provider_ids: {
        pinwheel: "adde7178-43cd-4cc6-8857-65dfc54a77e8",
        argyle: "item_000038249"
      }
    }
  ]
end
