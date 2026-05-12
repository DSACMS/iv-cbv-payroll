class DemoLauncherController < ApplicationController
  helper_method :session_timeout_enabled?
  before_action :set_demo_flow, only: [ :advanced, :launcher ]

  def advanced; end

  def launcher; end

  def create
    flow_type = launcher_params[:flow_type]
    client_agency_id = launcher_params[:client_agency_id]
    launch_type = launcher_params[:launch_type]
    test_scenario = launcher_params[:test_scenario]
    overrides = launch_overrides(flow_type)

    url = if flow_type == "cbv"
            if launch_type == "generic"
              build_cbv_generic_url(client_agency_id, overrides)
            else
              build_cbv_tokenized_url(client_agency_id, overrides)
            end
          elsif test_scenario.in?(FAKE_SCENARIO_KEYS)
            build_fake_test_scenario_url(test_scenario, client_agency_id, overrides)
          elsif test_scenario.present?
            build_test_scenario_url(test_scenario, client_agency_id, overrides)
          elsif launch_type == "generic"
            build_generic_url(client_agency_id, overrides)
          else
            build_tokenized_url(client_agency_id, overrides)
          end

    if request.format.json?
      render json: { url: url }
    else
      redirect_to url, allow_other_host: true
    end
  end

  def simple_create
    raw = params.fetch(:demo_launcher, params)
    if raw.key?(:reporting_window_start) || raw.key?(:demo_timeout)
      return render json: { error: "Parameter not allowed" }, status: :unprocessable_entity
    end

    permitted = simple_launcher_params

    unless permitted[:flow_type].in?(%w[cbv activity])
      return render json: { error: "Invalid flow_type" }, status: :unprocessable_entity
    end

    unless permitted[:client_agency_id].in?(Rails.application.config.client_agencies.client_agency_ids)
      return render json: { error: "Invalid client_agency_id" }, status: :unprocessable_entity
    end

    if permitted[:reporting_window].present? && !permitted[:reporting_window].in?(%w[application renewal])
      return render json: { error: "Invalid reporting_window" }, status: :unprocessable_entity
    end

    if permitted[:reporting_window_months].present? && !permitted[:reporting_window_months].to_i.between?(1, 6)
      return render json: { error: "reporting_window_months must be between 1 and 6" }, status: :unprocessable_entity
    end

    if permitted[:renewal_required_months].present? && !permitted[:renewal_required_months].to_i.between?(1, 6)
      return render json: { error: "renewal_required_months must be between 1 and 6" }, status: :unprocessable_entity
    end

    if permitted[:test_scenario].present? && !permitted[:test_scenario].in?(FAKE_SCENARIO_KEYS + TEST_SCENARIOS.keys)
      return render json: { error: "Invalid test_scenario" }, status: :unprocessable_entity
    end

    unless permitted[:launch_type].in?(%w[generic tokenized])
      return render json: { error: "Invalid launch_type" }, status: :unprocessable_entity
    end

    if permitted[:launch_type] == "generic" && permitted[:flow_type] == "activity"
      return render json: { error: "Generic launch is not supported for activity flow" }, status: :unprocessable_entity
    end

    flow_type = permitted[:flow_type]
    client_agency_id = permitted[:client_agency_id]
    launch_type = permitted[:launch_type]
    test_scenario = permitted[:test_scenario]
    overrides = simple_launch_overrides(flow_type)

    url = if flow_type == "cbv"
            if launch_type == "generic"
              build_cbv_generic_url(client_agency_id, overrides)
            else
              build_cbv_tokenized_url(client_agency_id, overrides)
            end
          elsif test_scenario.in?(FAKE_SCENARIO_KEYS)
            build_fake_test_scenario_url(test_scenario, client_agency_id, overrides)
          elsif test_scenario.present?
            build_test_scenario_url(test_scenario, client_agency_id, overrides)
          else
            build_tokenized_url(client_agency_id, overrides)
          end

    if request.format.json?
      render json: { url: url }
    else
      redirect_to url, allow_other_host: true
    end
  end

  private

  def set_demo_flow
    set_flow_session(nil, :activity)
  end

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

  def launch_overrides(flow_type)
    overrides = if flow_type == "cbv"
                  launcher_params.slice(:demo_timeout).select { |_, v| v.present? }
                else
                  allowed_overrides = [ :reporting_window, :reporting_window_months, :reporting_window_start, :demo_timeout ]
                  allowed_overrides << :renewal_required_months if launcher_params[:reporting_window] == "renewal"
                  launcher_params.slice(*allowed_overrides).select { |_, v| v.present? }
                end

    if overrides[:reporting_window_start].present?
      overrides[:reporting_window_start] = normalize_date_param(overrides[:reporting_window_start])
    end

    overrides
  end

  def launcher_params
    params.fetch(:demo_launcher, params).permit(
      :test_scenario,
      :flow_type,
      :client_agency_id,
      :reporting_window,
      :reporting_window_months,
      :renewal_required_months,
      :reporting_window_start,
      :demo_timeout,
      :launch_type
    )
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

  def simple_launcher_params
    params.fetch(:demo_launcher, params).permit(
      :flow_type,
      :client_agency_id,
      :reporting_window,
      :reporting_window_months,
      :renewal_required_months,
      :test_scenario,
      :launch_type
    )
  end

  def simple_launch_overrides(flow_type)
    return {} if flow_type == "cbv"

    allowed_overrides = [ :reporting_window, :reporting_window_months ]
    allowed_overrides << :renewal_required_months if simple_launcher_params[:reporting_window] == "renewal"
    simple_launcher_params.slice(*allowed_overrides).select { |_, v| v.present? }
  end
end
