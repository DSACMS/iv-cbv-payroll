class Cbv::GenericLinksController < Cbv::BaseController
  skip_before_action :set_cbv_flow
  skip_after_action :capture_page_view
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
    applicant.reset_applicant_attributes
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

  def track_generic_link_clicked_event(cbv_flow, is_new_session)
    # Skip tracking this event for a specific user agent, since we tend
    # to get a ton of traffic from it during LA SMS sends
    return if request.user_agent.match?(/go-http-client/i)

    event_logger.track(TrackEvent::ApplicantClickedGenericLink, request, {
      time: Time.now.to_i,
      cbv_applicant_id: cbv_flow.cbv_applicant_id,
      cbv_flow_id: cbv_flow.id,
      client_agency_id: cbv_flow.client_agency_id,
      origin: params[:origin],
      is_new_session: is_new_session
    })
  end
end
