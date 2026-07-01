FactoryBot.define do
  factory :household do
    client_agency_id { "sandbox" }
    sequence(:reference_id) { |n| "household-#{n}" }
  end
end
