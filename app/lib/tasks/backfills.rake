namespace :backfills do
  desc "Back-fill cbv_applicants from existing cbv data"
  task cbv_applicants: :environment do
    CbvFlowInvitation.transaction do
      CbvFlowInvitation.find_each do |cbv_flow_invitation|
        cbv_applicant = CbvApplicant.create_from_invitation(cbv_flow_invitation)
        cbv_flow_invitation.cbv_flows.update_all(cbv_applicant_id: cbv_applicant.id)
      end
    end
  end
end
