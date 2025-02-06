FactoryBot.define do
  factory :user do
    site_id { "sandbox" }
    sequence(:email) { |n| "user#{n}@example.com" }

    trait :with_access_token do
      after(:build) do |user, evaluator|
        user.api_access_tokens = [
          create(:api_access_token, user: user)
        ]
      end
    end
  end
end
