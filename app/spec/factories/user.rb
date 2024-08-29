r = Random.new
n = r.rand(99999999)
FactoryBot.define do
  factory :user do
    site_id { "sandbox" }
    email { "user#{n}@example.com" }
  end
end
