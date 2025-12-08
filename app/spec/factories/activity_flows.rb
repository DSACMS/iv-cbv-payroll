FactoryBot.define do
  factory :activity_flow do
    cbv_applicant { association :cbv_applicant }
    device_id { SecureRandom.uuid }
  end
end
