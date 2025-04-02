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
        pinwheel_id = item[:provider_ids][:pinwheel]
        argyle_id = item[:provider_ids][:argyle]

        provider_id = nil
        provider_name = nil

        if aggregator_config.include?(:argyle) && aggregator_config.include?(:pinwheel)
          if argyle_id != nil
            provider_id = argyle_id
            provider_name = "argyle"
          elsif pinwheel_id != nil
            provider_id = pinwheel_id
            provider_name = "pinwheel"
          end
        else
          if argyle_id != nil && aggregator_config.include?(:argyle)
            provider_id = argyle_id
            provider_name = "argyle"
          elsif pinwheel_id != nil && aggregator_config.include?(:pinwheel)
            provider_id = pinwheel_id
            provider_name = "pinwheel"
          end
        end

        new(
          provider_name: provider_name,
          provider_options: ProviderOptions.new(
            response_type: item[:response_type],
            provider_id: provider_id
          ),
          name: item[:name],
          logo_url: item[:logo_url]
        )
      end
      tmp_items.select { |i| i.provider_options[:provider_id] != nil }
    end
  end
end
