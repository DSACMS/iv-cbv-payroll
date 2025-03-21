module Aggregators::ResponseObjects
  SearchResult = Struct.new(:provider_name, :provider_options, :name, :logo_url, keyword_init: true) do
    def self.from_pinwheel(response_body)
      new(
        provider_name: :pinwheel,
        provider_options: {
          response_type: response_body["response_type"],
          provider_id: response_body["id"]
        },
        name: response_body["name"],
        logo_url: response_body["logo_url"]
      )
    end

    def self.from_argyle(response_body)
      new(
        provider_name: :argyle,
        provider_options: {
          response_type: response_body["kind"],
          provider_id: response_body["id"]
        },
        name: response_body["name"],
        logo_url: response_body["logo_url"]
      )
    end
  end
end
