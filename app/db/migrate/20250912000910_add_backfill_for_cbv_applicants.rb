class AddBackfillForCbvApplicants < ActiveRecord::Migration[7.2]
  def change
    CbvApplicant.includes(:cbv_flow_invitations).find_each do |cbv_applicant|
      next if cbv_applicant.cbv_flow_invitations.none?

      cbv_applicant.update(cbv_flow_invitation_id: cbv_applicant.cbv_flow_invitations.first.id)
    end
  end
end
