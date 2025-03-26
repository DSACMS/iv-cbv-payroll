class Cbv::ApplicantInformationsController < Cbv::BaseController
  include Cbv::PinwheelDataHelper
  before_action :set_cbv_applicant, only: %i[show update]
  before_action :redirect_when_in_invitation_flow, :redirect_when_info_present, only: :show

  def show
  end

  def update
    begin
      @cbv_applicant.update!(applicant_params[:cbv_applicant])
    rescue => e
      Rails.logger.error("Error updating applicant: #{e.message}")
      flash[:alert] = t(".error_updating_applicant")
      return redirect_to cbv_flow_applicant_information_path
    end

    missing_attrs = @required_applicant_attrs.reject do |attr|
      @cbv_applicant.send(attr).present?
    end

    if missing_attrs.any?
      missing_attrs.each do |attr|
        @cbv_applicant.errors.add(attr, t("cbv.applicant_informations.#{@cbv_flow.client_agency_id}.fields.#{attr}.blank"))
      end

      error_count = @cbv_applicant.errors.size
      error_header = "#{helpers.pluralize(error_count, 'error')} occurred" # TODO: is this properly tokenized?

      # Collect error messages without attribute names
      error_messages = @cbv_applicant.errors.messages.values.flatten.map { |msg| "<li>#{msg}</li>" }.join
      error_messages = "<ul>#{error_messages}</ul>"

      flash.now[:alert_heading] = error_header
      flash.now[:alert] = error_messages.html_safe

      return render :show, status: :unprocessable_entity
    end

    redirect_to next_path
  end

  def redirect_when_info_present
    return if params[:force_show] == "true"

    missing_attrs = @required_applicant_attrs.reject do |attr|
      @cbv_applicant.send(attr).present?
    end

    redirect_to next_path if missing_attrs.empty?
  end

  def redirect_when_in_invitation_flow
    redirect_to next_path if @cbv_flow.cbv_flow_invitation.present?
  end

  def applicant_params
    params.fetch("cbv_applicant_#{@cbv_flow.client_agency_id}", {}).permit(
      cbv_applicant: @applicant_attrs
    )
  end

  def set_cbv_applicant
    @cbv_applicant = @cbv_flow.cbv_applicant
  end
end
