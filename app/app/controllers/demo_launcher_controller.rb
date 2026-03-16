class DemoLauncherController < ApplicationController
  helper_method :session_timeout_enabled?

  def show
    set_flow_session(nil, :activity)
  end

  def create
    flow_type = params[:flow_type]
    client_agency_id = params[:client_agency_id]
    launch_type = params[:launch_type]
    nsc_test_user = params[:nsc_test_user]

    overrides = if flow_type == "cbv"
                  params.permit(:demo_timeout).select { |_, v| v.present? }
                else
                  params.permit(:reporting_window, :reporting_window_months, :demo_timeout).select { |_, v| v.present? }
                end

    url = if flow_type == "cbv"
            if launch_type == "generic"
              build_cbv_generic_url(client_agency_id, overrides)
            else
              build_cbv_tokenized_url(client_agency_id, overrides)
            end
          elsif launch_type == "generic"
            build_generic_url(client_agency_id, overrides)
          elsif nsc_test_user.present?
            build_nsc_test_user_url(nsc_test_user, client_agency_id, overrides)
          elsif params[:fake_test_user].present?
            build_fake_test_user_url(params[:fake_test_user], client_agency_id, overrides)
          else
            build_tokenized_url(client_agency_id, overrides)
          end

    redirect_to url, allow_other_host: true
  end

  private

  def session_timeout_enabled?
    false
  end

  def launcher_url_options
    opts = { host: request.host_with_port, protocol: request.protocol }
    # When behind a reverse proxy (e.g., ngrok), explicitly set port to nil so the scheme's default port is used.
    opts[:port] = nil if request.headers["X-Forwarded-Proto"].present?
    opts
  end

  def build_cbv_generic_url(client_agency_id, overrides)
    Rails.application.routes.url_helpers.cbv_flow_new_url(
      client_agency_id: client_agency_id,
      **launcher_url_options,
      **overrides
    )
  end

  def build_cbv_tokenized_url(client_agency_id, overrides)
    user = User.find_or_create_by(
      email: "demolauncher+#{client_agency_id}@navapbc.com",
      client_agency_id: client_agency_id
    )
    user.update(is_service_account: true)

    invitation = CbvFlowInvitation.create!(
      user: user,
      client_agency_id: client_agency_id,
      language: "en",
      email_address: user.email,
      cbv_applicant_attributes: {
        first_name: "Demo",
        last_name: "User",
        client_agency_id: client_agency_id,
        case_number: "demo-#{SecureRandom.hex(4)}",
        snap_application_date: Date.today
      }
    )
    url = invitation.to_url
    uri = URI.parse(url)
    uri.scheme = request.scheme
    uri.host = request.host
    uri.port = request.headers["X-Forwarded-Proto"].present? ? nil : request.port
    existing_params = URI.decode_www_form(uri.query || "")
    existing_params << [ "client_agency_id", client_agency_id ]
    overrides.to_h.each { |k, v| existing_params << [ k, v ] }
    uri.query = URI.encode_www_form(existing_params)
    uri.to_s
  end

  def build_generic_url(client_agency_id, overrides)
    Rails.application.routes.url_helpers.activities_flow_new_url(
      client_agency_id: client_agency_id,
      **launcher_url_options,
      **overrides
    )
  end

  def build_tokenized_url(client_agency_id, overrides)
    invitation = ActivityFlowInvitation.create!(
      client_agency_id: client_agency_id,
      reference_id: "demo-#{SecureRandom.hex(4)}"
    )
    invitation.to_url(
      **launcher_url_options,
      **overrides
    )
  end

  FAKE_TEST_USERS = {
    "partial_enrollment" => {
      first_name: "Sam",
      last_name: "Testuser",
      date_of_birth: "1990-05-15",
      school_name: "Greenfield Community College"
    }
  }.freeze

  NSC_TEST_USERS = {
    "lynette" => { first_name: "Lynette", last_name: "Oyola", date_of_birth: "1988-10-24" },
    "rick" => { first_name: "Rick", last_name: "Banas", date_of_birth: "1979-08-18" },
    "dominique" => { first_name: "Dominique", last_name: "Ricardo", date_of_birth: "1978-01-12" },
    "linda" => { first_name: "Linda", last_name: "Cooper", date_of_birth: "1999-01-01" }
  }.freeze

  def build_nsc_test_user_url(user_key, client_agency_id, overrides)
    user_data = NSC_TEST_USERS[user_key]
    raise ArgumentError, "Unknown NSC test user: #{user_key}" unless user_data

    cbv_applicant = CbvApplicant.create!(
      first_name: user_data[:first_name],
      last_name: user_data[:last_name],
      date_of_birth: Date.parse(user_data[:date_of_birth]),
      client_agency_id: client_agency_id
    )

    invitation = ActivityFlowInvitation.create!(
      cbv_applicant: cbv_applicant,
      client_agency_id: client_agency_id,
      reference_id: "nsc-demo-#{user_key}"
    )

    invitation.to_url(
      **launcher_url_options,
      **overrides
    )
  end

  def build_fake_test_user_url(user_key, client_agency_id, overrides)
    user_data = FAKE_TEST_USERS[user_key]
    raise ArgumentError, "Unknown fake test user: #{user_key}" unless user_data

    cbv_applicant = CbvApplicant.create!(
      first_name: user_data[:first_name],
      last_name: user_data[:last_name],
      date_of_birth: Date.parse(user_data[:date_of_birth]),
      client_agency_id: client_agency_id
    )

    invitation = ActivityFlowInvitation.create!(
      cbv_applicant: cbv_applicant,
      client_agency_id: client_agency_id,
      reference_id: "fake-demo-#{user_key}"
    )

    flow = ActivityFlow.create_from_invitation(
      invitation,
      cookies.permanent.signed[:device_id] || SecureRandom.uuid,
      overrides.to_h.symbolize_keys
    )

    if overrides[:reporting_window_months].present?
      flow.update!(reporting_window_months: overrides[:reporting_window_months].to_i)
    end

    identity = Identity.create!(
      first_name: user_data[:first_name],
      last_name: user_data[:last_name],
      date_of_birth: Date.parse(user_data[:date_of_birth])
    )
    flow.update!(identity: identity)

    education_activity = flow.education_activities.create!(
      data_source: :partially_self_attested,
      status: :succeeded
    )

    reporting_window = flow.reporting_window_range
    education_activity.nsc_enrollment_terms.create!(
      school_name: user_data[:school_name],
      first_name: user_data[:first_name],
      last_name: user_data[:last_name],
      enrollment_status: :less_than_half_time,
      term_begin: reporting_window.begin,
      term_end: reporting_window.end
    )

    set_flow_session(flow.id, :activity)
    activities_flow_root_url(**launcher_url_options)
  end
end
