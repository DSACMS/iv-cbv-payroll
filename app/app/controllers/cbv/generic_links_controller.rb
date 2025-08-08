class Cbv::GenericLinksController < Cbv::BaseController
  skip_before_action :set_cbv_flow, :capture_page_view
  before_action :ensure_valid_client_agency_id
  before_action :check_if_pilot_ended_for_agency

  def show
    @cbv_flow, is_new_session = find_or_create_cbv_flow

    session[:cbv_flow_id] = @cbv_flow.id
    cookies.permanent.encrypted[:cbv_applicant_id] = @cbv_flow.cbv_applicant_id

    track_generic_link_clicked_event(@cbv_flow, is_new_session)
    redirect_to next_path
  end

  private

  def ensure_valid_client_agency_id
    return if agency_config.client_agency_ids.include?(params[:client_agency_id])

    redirect_to root_url, flash: { info: t("cbv.error_invalid_link") }
  end

  def check_if_pilot_ended_for_agency
    agency = agency_config[params[:client_agency_id]]
    if agency&.pilot_ended
      redirect_to root_url
    end
  end

  def find_or_create_cbv_flow
    existing_applicant = find_existing_applicant_from_cookie

    if existing_applicant
      create_flow_with_existing_applicant(existing_applicant)
    else
      create_flow_with_new_applicant
    end
  end

  def find_existing_applicant_from_cookie
    applicant_id = cookies.encrypted[:cbv_applicant_id]
    return nil unless applicant_id.present?

    find_existing_applicant(applicant_id)
  end

  def create_flow_with_existing_applicant(applicant)
    reset_applicant_information(applicant)
    cbv_flow = CbvFlow.create(cbv_applicant: applicant, client_agency_id: params[:client_agency_id])
    [ cbv_flow, false ]
  end

  def create_flow_with_new_applicant
    cbv_flow = CbvFlow.create_without_invitation(params[:client_agency_id])
    [ cbv_flow, true ]
  end

  def find_existing_applicant(applicant_id)
    CbvApplicant.find_by(id: applicant_id, client_agency_id: params[:client_agency_id])
  end

  def reset_applicant_information(applicant)
    clear_attributes = applicant.applicant_attributes.index_with(nil)
    applicant.update!(clear_attributes)
  end

  def track_generic_link_clicked_event(cbv_flow, is_new_session)
    event_logger.track("ApplicantClickedGenericLink", request, {
      cbv_applicant_id: cbv_flow.cbv_applicant_id,
      cbv_flow_id: cbv_flow.id,
      client_agency_id: cbv_flow.client_agency_id,
      origin: params[:origin],
      is_new_session: is_new_session
    })
  rescue => ex
    Rails.logger.error "Unable to track event (ApplicantClickedGenericLink): #{ex}"
    raise unless Rails.env.production?
  end
end
