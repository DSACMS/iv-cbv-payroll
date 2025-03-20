class Cbv::ApplicantInformationsController < Cbv::BaseController
  before_action :redirect_when_in_invitation_flow, :redirect_when_info_present

  def show
  end

  def update
    redirect_to next_path
  end

  def redirect_when_info_present
    # Determine if we have enough information about the applicant to continue
    return if !@cbv_flow.cbv_applicant.case_number.present?
    return if !@cbv_flow.cbv_applicant.first_name.present?
    return if !@cbv_flow.cbv_applicant.last_name.present?

    redirect_to next_path
  end

  def redirect_when_in_invitation_flow
    redirect_to next_path if @cbv_flow.cbv_flow_invitation.present?
  end
end
