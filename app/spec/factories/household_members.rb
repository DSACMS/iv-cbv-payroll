FactoryBot.define do
  factory :household_member do
    household
    activity_flow_invitation
    sequence(:reference_id) { |n| "member-#{n}" }
    display_name { "Avery Johnson" }
    role_label { "Parent" }
  end
end
