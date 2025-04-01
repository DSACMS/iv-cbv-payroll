FactoryBot.define do
  factory :cbv_flow_invitation, class: "CbvFlowInvitation" do
    client_agency_id { "sandbox" }
    email_address { "test@example.com" }
    language { :en }
    user

    cbv_applicant

    trait :nyc do
      client_agency_id { "nyc" }

      cbv_applicant { create(:cbv_applicant, :nyc) }
    end

    trait :ma do
      client_agency_id { "ma" }

      cbv_applicant { create(:cbv_applicant, :ma) }
    end

    trait :az_des do
      client_agency_id { "az_des" }

      cbv_applicant { create(:cbv_applicant, :az_des) }
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
