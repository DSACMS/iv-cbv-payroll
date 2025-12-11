class AddCbvApplicantToActivityFlows < ActiveRecord::Migration[7.2]
  def change
    ActivityFlow.destroy_all
    add_reference :activity_flows, :cbv_applicant, null: false, foreign_key: true
  end
end
