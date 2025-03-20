class Cbv::ApplicantInformationsController < Cbv::BaseController
  before_action :redirect_when_info_present

  def show
  end

  def redirect_when_info_present
    # Determine if we have enough information about the applicant to continue
    return if !@cbv_flow.cbv_applicant.case_number.present?
    return if !@cbv_flow.cbv_applicant.first_name.present?
    return if !@cbv_flow.cbv_applicant.last_name.present?

    redirect_to next_path
  end
end
