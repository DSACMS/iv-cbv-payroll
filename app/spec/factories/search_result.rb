FactoryBot.define do
  factory :search_result, class: Aggregators::ResponseObjects::SearchResult do
    provider_name { [ :pinwheel, :argyle ].sample }
    sequence(:name) { |n| "employer#{n}" }
    logo_url { nil }

    sequence(:provider_options) do |n|
      Aggregators::ResponseObjects::ProviderOptions.new(
        provider_id: "#{n}",
        response_type: [
          "employer",
          "gig"
        ].sample
      )
    end
  end
end
