class DemoLauncherController < ApplicationController
  helper_method :session_timeout_enabled?

  def show
    set_flow_session(nil, :activity)
  end

  def create
    flow_type = params[:flow_type]
    client_agency_id = params[:client_agency_id]
    launch_type = params[:launch_type]
    overrides = if flow_type == "cbv"
                  params.permit(:demo_timeout).select { |_, v| v.present? }
                else
                  params.permit(:reporting_window, :reporting_window_months, :reporting_window_start, :demo_timeout).select { |_, v| v.present? }
                end

    if overrides[:reporting_window_start].present?
      overrides[:reporting_window_start] = normalize_date_param(overrides[:reporting_window_start])
    end

    url = if flow_type == "cbv"
            if launch_type == "generic"
              build_cbv_generic_url(client_agency_id, overrides)
            else
              build_cbv_tokenized_url(client_agency_id, overrides)
            end
          elsif params[:test_scenario].in?(FAKE_SCENARIO_KEYS)
            build_fake_test_scenario_url(params[:test_scenario], client_agency_id, overrides)
          elsif params[:test_scenario].present?
            build_test_scenario_url(params[:test_scenario], client_agency_id, overrides)
          elsif launch_type == "generic"
            build_generic_url(client_agency_id, overrides)
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

  def normalize_date_param(date_str)
    if date_str.match?(%r{/})
      Date.strptime(date_str, "%m/%d/%Y").strftime("%Y-%m-%d")
    else
      date_str
    end
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

  TEST_SCENARIOS = {
    "lynette" => { first_name: "Lynette", last_name: "Oyola", date_of_birth: "1988-10-24" },
    "rick" => { first_name: "Rick", last_name: "Banas", date_of_birth: "1979-08-18" },
    "dominique" => { first_name: "Dominique", last_name: "Ricardo", date_of_birth: "1978-01-12" },
    "linda" => { first_name: "Linda", last_name: "Cooper", date_of_birth: "1999-01-01" }
  }.freeze

  FAKE_SCENARIO_KEYS = DemoLauncher::FakeNscScenarios.scenario_keys.freeze

  def build_test_scenario_url(scenario_key, client_agency_id, overrides)
    user_data = TEST_SCENARIOS[scenario_key]
    raise ArgumentError, "Unknown test scenario: #{scenario_key}" unless user_data

    cbv_applicant = CbvApplicant.create!(
      first_name: user_data[:first_name],
      last_name: user_data[:last_name],
      date_of_birth: Date.parse(user_data[:date_of_birth]),
      client_agency_id: client_agency_id
    )

    invitation = ActivityFlowInvitation.create!(
      cbv_applicant: cbv_applicant,
      client_agency_id: client_agency_id,
      reference_id: "demo-#{scenario_key}"
    )

    invitation.to_url(
      **launcher_url_options,
      **overrides
    )
  end

  def build_fake_test_scenario_url(scenario_key, client_agency_id, overrides)
    user_data = DemoLauncher::FakeNscScenarios.by_key(scenario_key)
    raise ArgumentError, "Unknown test scenario: #{scenario_key}" unless user_data

    cbv_applicant = CbvApplicant.create!(
      first_name: user_data.first_name,
      last_name: user_data.last_name,
      date_of_birth: user_data.date_of_birth,
      client_agency_id: client_agency_id
    )

    invitation = ActivityFlowInvitation.create!(
      cbv_applicant: cbv_applicant,
      client_agency_id: client_agency_id,
      reference_id: "demo-#{scenario_key}"
    )
    merged_overrides = overrides.to_h

    invitation.to_url(
      **launcher_url_options,
      **merged_overrides
    )
  end
end
