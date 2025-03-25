class Cbv::ApplicantInformationsController < Cbv::BaseController
  include Cbv::PinwheelDataHelper
  before_action :set_cbv_applicant, only: %i[show update]
  before_action :redirect_when_in_invitation_flow, :redirect_when_info_present
  before_action :set_identities, only: %i[show update]

  def show
  end

  def update
    begin
      @cbv_applicant.update!(applicant_params[:cbv_applicant])
    rescue => e
      Rails.logger.error("Error updating applicant: #{e.message}")
      flash[:alert] = "An error occurred while updating the applicant information. Please try again."
      return redirect_to cbv_flow_applicant_information_path
    end

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

  def applicant_params
    params.fetch("cbv_applicant_#{@cbv_flow.client_agency_id}", {}).permit(
      :cbv_applicant => [
        :first_name,
        :middle_name,
        :last_name,
        :case_number
      ]
    )
  end

  def set_cbv_applicant
    @cbv_applicant = @cbv_flow.cbv_applicant
  end
end
