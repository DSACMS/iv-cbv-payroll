FactoryBot.define do
  factory :activity_flow_invitation do
    client_agency_id { "sandbox" }
    reference_id { nil }
    cbv_applicant { nil }
  end
end
