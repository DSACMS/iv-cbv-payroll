FactoryBot.define do
  factory :employment_activity do
    activity_flow { association(:activity_flow,
                           volunteering_activities_count: 0,
                           job_training_activities_count: 0,
                           education_activities_count: 0) }
    employer_name { "Gainesville Wrecking" }
    street_address { "942 W Harlan Ave" }
    city { "Gainesville" }
    state { "FL" }
    zip_code { "32611" }
    is_self_employed { false }
    contact_name { "Donny Spears" }
    contact_email { "donny@gainesvillewrecking.com" }
    contact_phone_number { "(415) 344-8009" }
  end
end
