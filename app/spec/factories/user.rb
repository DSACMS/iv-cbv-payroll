FactoryBot.define do
  factory :user do
    site_id { "sandbox" }
    sequence(:email) { |n| "user#{n}@example.com" }
    # association :api_access_token, factory: [ :api_access_token ]
  end
end
