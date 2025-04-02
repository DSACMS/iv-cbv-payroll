module Aggregators::ResponseObjects
  ProviderOptions = Struct.new(:response_type, :provider_id)
  SearchResult = Struct.new(:provider_name, :provider_options, :name, :logo_url, keyword_init: true) do
    def self.from_pinwheel(response_body)
      new(
        provider_name: :pinwheel,
        provider_options: ProviderOptions.new(
          response_type: response_body["response_type"],
          provider_id: response_body["id"]
        ),
        name: response_body["name"],
        logo_url: response_body["logo_url"]
      )
    end

    def self.from_argyle(response_body)
      new(
        provider_name: :argyle,
        provider_options: ProviderOptions.new(
          response_type: response_body["kind"],
          provider_id: response_body["id"]
        ),
        name: response_body["name"],
        logo_url: response_body["logo_url"]
      )
    end

    def self.from_aggregator_options(items, aggregator_config)
      tmp_items = items.map do |item|
        provider = determine_provider(item[:provider_ids], aggregator_config)

        new(
          provider_name: provider[:provider_name],
          provider_options: ProviderOptions.new(
            response_type: item[:response_type],
            provider_id: provider[:provider_id]
          ),
          name: item[:name],
          logo_url: item[:logo_url]
        )
      end
      tmp_items.select { |i| i.provider_options[:provider_id] != nil }
    end

    private

    def self.determine_provider(provider_ids, aggregator_config)
      if provider_ids[:argyle] && aggregator_config.include?(:argyle)
        { provider_name: :argyle, provider_id: provider_ids[:argyle] }
      elsif provider_ids[:pinwheel] && aggregator_config.include?(:pinwheel)
        { provider_name: :pinwheel, provider_id: provider_ids[:pinwheel] }
      else
        { provider_name: nil, provider_id: nil }
      end
    end
  end
end
