class LauncherController < ApplicationController
  helper_method :session_timeout_enabled?, :agency_activity_types
  before_action :set_launcher_flow, only: [ :advanced, :launcher ]
  before_action :validate_household_launch, only: :create

  def advanced; end

  def launcher; end

  def create
    flow_type = launcher_params[:flow_type]
    client_agency_id = launcher_params[:client_agency_id]
    launch_type = launcher_params[:launch_type]
    test_scenario = launcher_params[:test_scenario]
    overrides = launch_overrides(flow_type)

    url = if launch_type == "household"
            build_household_url(client_agency_id, overrides)
          elsif flow_type == "cbv"
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
    raw = params.fetch(:launcher, params)
    if raw.key?(:reporting_window_start) || raw.key?(:launcher_timeout)
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

  def set_launcher_flow
    set_flow_session(nil, :activity)
  end

  def session_timeout_enabled?
    false
  end

  def agency_activity_types
    Rails.application.config.client_agencies.client_agency_ids.index_with do |agency_id|
      Rails.application.config.client_agencies[agency_id].activity_types.select { |_type, enabled| enabled }.keys
    end
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

  def build_pre_populated_activities
    activities = []
    month_strings = reporting_window_months_for_activities(launcher_params[:client_agency_id])

    if launcher_params[:volunteering_enabled] == "1"
      hours = launcher_params[:volunteering_hours_per_month].to_i
      activities << {
        "type" => "volunteering",
        "organization_name" => launcher_params[:volunteering_organization_name].presence || "Red Cross",
        "months" => month_strings.map { |m| { "month" => m, "hours" => hours } }
      }
    end

    if launcher_params[:employment_enabled] == "1"
      hours = launcher_params[:employment_hours_per_month].to_i
      gross_income = launcher_params[:employment_gross_income_per_month].to_i
      activities << {
        "type" => "employment",
        "employer_name" => launcher_params[:employment_employer_name].presence || "Acme Corp",
        "months" => month_strings.map { |m| { "month" => m, "hours" => hours, "gross_income" => gross_income } }
      }
    end

    if launcher_params[:education_enabled] == "1"
      hours = launcher_params[:education_hours_per_month].to_i
      activities << {
        "type" => "education",
        "school_name" => launcher_params[:education_school_name].presence || "Springfield Community College",
        "months" => month_strings.map { |m| { "month" => m, "hours" => hours } }
      }
    end

    if launcher_params[:job_training_enabled] == "1"
      hours = launcher_params[:job_training_hours_per_month].to_i
      activities << {
        "type" => "job_training",
        "program_name" => launcher_params[:job_training_program_name].presence || "Career Prep",
        "organization_name" => launcher_params[:job_training_organization_name].presence || "Goodwill",
        "months" => month_strings.map { |m| { "month" => m, "hours" => hours } }
      }
    end

    activities
  end

  def reporting_window_months_for_activities(client_agency_id)
    range = ActivityFlow.expected_reporting_window_range(
      client_agency_id,
      **pre_populated_reporting_window_options(client_agency_id)
    )
    months = []
    current = range.begin.beginning_of_month
    while current <= range.end
      months << current.strftime("%Y-%m-%d")
      current = current.next_month
    end
    months
  end

  def pre_populated_reporting_window_options(client_agency_id)
    reporting_window_type = launcher_params[:reporting_window] == "renewal" ? "renewal" : "application"
    month_count = pre_populated_reporting_window_month_count(client_agency_id)
    reference_date = Date.current

    if launcher_params[:reporting_window_start].present?
      start_date = Date.parse(normalize_date_param(launcher_params[:reporting_window_start])).beginning_of_month
      reference_date = start_date + month_count.months
    end

    {
      reporting_window_type: reporting_window_type,
      reference_date: reference_date,
      months_override: month_count
    }
  end

  def pre_populated_reporting_window_month_count(client_agency_id)
    return launcher_params[:reporting_window_months].to_i if launcher_params[:reporting_window_months].present?
    return ActivityFlow::DEFAULT_RENEWAL_REPORTING_WINDOW_MONTHS if launcher_params[:reporting_window] == "renewal"

    Rails.application.config.client_agencies[client_agency_id]&.application_reporting_months ||
      ActivityFlow::DEFAULT_APPLICATION_REPORTING_WINDOW_MONTHS
  end

  def create_launcher_activity_flow_invitation!(attributes)
    ActivityFlowInvitation.create!(
      attributes.merge(
        pre_populated_activities: build_pre_populated_activities,
        skip_month_window_validation: true
      )
    )
  end

  def launch_overrides(flow_type)
    overrides = if flow_type == "cbv"
                  launcher_params.slice(:launcher_timeout).select { |_, v| v.present? }
                else
                  allowed_overrides = [ :reporting_window, :reporting_window_months, :reporting_window_start, :launcher_timeout ]
                  allowed_overrides << :renewal_required_months if launcher_params[:reporting_window] == "renewal"
                  launcher_params.slice(*allowed_overrides).select { |_, v| v.present? }
                end

    if overrides[:reporting_window_start].present?
      overrides[:reporting_window_start] = normalize_date_param(overrides[:reporting_window_start])
    end

    overrides
  end

  def launcher_params
    params.fetch(:launcher, params).permit(
      :test_scenario,
      :flow_type,
      :client_agency_id,
      :reporting_window,
      :reporting_window_months,
      :renewal_required_months,
      :reporting_window_start,
      :launcher_timeout,
      :launch_type,
      :volunteering_enabled,
      :volunteering_organization_name,
      :volunteering_hours_per_month,
      :employment_enabled,
      :employment_employer_name,
      :employment_hours_per_month,
      :employment_gross_income_per_month,
      :education_enabled,
      :education_school_name,
      :education_hours_per_month,
      :job_training_enabled,
      :job_training_program_name,
      :job_training_organization_name,
      :job_training_hours_per_month,
      household_archetypes: []
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
      email: "launcher+#{client_agency_id}@navapbc.com",
      client_agency_id: client_agency_id
    )
    user.update(is_service_account: true)

    invitation = CbvFlowInvitation.create!(
      user: user,
      client_agency_id: client_agency_id,
      language: "en",
      email_address: user.email,
      cbv_applicant_attributes: {
        first_name: "Sample",
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
    invitation = create_launcher_activity_flow_invitation!(
      client_agency_id: client_agency_id,
      reference_id: "demo-#{SecureRandom.hex(4)}"
    )
    invitation.to_url(
      **launcher_url_options,
      **overrides
    )
  end

  def build_household_url(client_agency_id, launcher_overrides)
    household = Launcher::HouseholdScenario.create!(
      archetype_keys: @household_archetype_keys,
      client_agency_id: client_agency_id,
      launcher_overrides: launcher_overrides
    )
    household.to_url(**launcher_url_options)
  end

  def validate_household_launch
    return unless launcher_params[:launch_type] == "household"

    @household_archetype_keys = resolved_household_archetype_keys

    if @household_archetype_keys.empty?
      return render_launcher_error(t("launcher.advanced.household.errors.no_archetypes_selected"))
    end

    unless household_available_for?(launcher_params[:client_agency_id])
      render_launcher_error(t("launcher.advanced.household.errors.unsupported_agency"))
    end
  end

  def resolved_household_archetype_keys
    Array(launcher_params[:household_archetypes]).filter_map(&:presence) &
      Launcher::HouseholdScenario.archetypes.keys
  end

  def household_available_for?(client_agency_id)
    agency_activity_types[client_agency_id].present?
  end

  def render_launcher_error(message)
    respond_to do |format|
      format.json { render json: { error: message }, status: :unprocessable_entity }
      format.html { redirect_to "/launcher/advanced", alert: message }
    end
  end

  TEST_SCENARIOS = {
    "lynette" => { first_name: "Lynette", last_name: "Oyola", date_of_birth: "1988-10-24" },
    "rick" => { first_name: "Rick", last_name: "Banas", date_of_birth: "1979-08-18" },
    "dominique" => { first_name: "Dominique", last_name: "Ricardo", date_of_birth: "1978-01-12" },
    "linda" => { first_name: "Linda", last_name: "Cooper", date_of_birth: "1999-01-01" }
  }.freeze

  FAKE_SCENARIO_KEYS = Launcher::FakeNscScenarios.scenario_keys.freeze

  def build_test_scenario_url(scenario_key, client_agency_id, overrides)
    user_data = TEST_SCENARIOS[scenario_key]
    raise ArgumentError, "Unknown test scenario: #{scenario_key}" unless user_data

    cbv_applicant = CbvApplicant.create!(
      first_name: user_data[:first_name],
      last_name: user_data[:last_name],
      date_of_birth: Date.parse(user_data[:date_of_birth]),
      client_agency_id: client_agency_id
    )

    invitation = create_launcher_activity_flow_invitation!(
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
    user_data = Launcher::FakeNscScenarios.by_key(scenario_key)
    raise ArgumentError, "Unknown test scenario: #{scenario_key}" unless user_data

    cbv_applicant = CbvApplicant.create!(
      first_name: user_data.first_name,
      last_name: user_data.last_name,
      date_of_birth: user_data.date_of_birth,
      client_agency_id: client_agency_id
    )

    invitation = create_launcher_activity_flow_invitation!(
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
    params.fetch(:launcher, params).permit(
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
