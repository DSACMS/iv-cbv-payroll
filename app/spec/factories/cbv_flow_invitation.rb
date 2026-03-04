FactoryBot.define do
  factory :cbv_flow_invitation, class: "CbvFlowInvitation" do
    client_agency_id { "sandbox" }
    email_address { "test@example.com" }
    language { :en }
    user

    cbv_applicant

    trait :sandbox do
      client_agency_id { "sandbox" }

      cbv_applicant { create(:cbv_applicant, :sandbox) }
    end

    trait :la_ldh do
      client_agency_id { "la_ldh" }

      cbv_applicant { create(:cbv_applicant, :la_ldh) }
    end

    transient do
      cbv_applicant_attributes { {} }
    end

    after(:build) do |cbv_flow_invitation, evaluator|
      if cbv_flow_invitation.cbv_applicant
        cbv_flow_invitation.cbv_applicant.update(evaluator.cbv_applicant_attributes)
      end
    end
  end
end
