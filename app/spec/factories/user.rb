FactoryBot.define do
  factory :user do
    site_id { "sandbox" }
    sequence(:email) { |n| "user#{n}@example.com" }
  end
end
