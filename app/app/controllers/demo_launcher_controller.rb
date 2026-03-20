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
    "linda" => { first_name: "Linda", last_name: "Cooper", date_of_birth: "1999-01-01" },
    "partial_enrollment_sam" => {
      first_name: "Sam", last_name: "Testuser", date_of_birth: "1990-05-15",
      school_names: [ "Greenfield Community College", "North Valley College" ]
    },
    "partial_enrollment_multi_term" => {
      first_name: "Nina",
      last_name: "Testuser",
      date_of_birth: "1990-05-15",
      reporting_window_months: 6,
      terms: [
        { school_name: "Greenfield Community College", enrollment_status: :less_than_half_time },
        { school_name: "Riverside Technical Institute", enrollment_status: :less_than_half_time }
      ]
    },
    "partial_enrollment_ziggy" => {
      first_name: "Ziggy", last_name: "Testuser", date_of_birth: "1992-07-19",
      school_names: [ "Sunrise Community College" ]
    },
    "partial_enrollment_casey" => {
      first_name: "Casey",
      last_name: "Testuser",
      date_of_birth: "1991-04-22",
      enrollments: [
        { school_name: "Pine Valley College", enrollment_status: :half_time },
        { school_name: "Riverside Community College", enrollment_status: :less_than_half_time }
      ]
    },
    "partial_enrollment_maya" => {
      first_name: "Maya",
      last_name: "Testuser",
      date_of_birth: "1993-09-11",
      terms: [
        { school_name: "River College", enrollment_status: :less_than_half_time },
        { school_name: "River College", enrollment_status: :less_than_half_time }
      ]
    },
    "summer_term_carryover_sage" => {
      first_name: "Sage",
      last_name: "Testuser",
      date_of_birth: "1994-08-03",
      terms: [
        {
          school_name: "Coastal State College",
          enrollment_status: :half_time,
          term_type: :qualifying_spring
        },
        {
          school_name: "Coastal State College",
          enrollment_status: :less_than_half_time,
          term_type: :summer_less_than_half_time
        }
      ]
    }
  }.freeze

  FAKE_SCENARIO_KEYS = %w[
    partial_enrollment_sam
    partial_enrollment_multi_term
    partial_enrollment_ziggy
    partial_enrollment_casey
    partial_enrollment_maya
    summer_term_carryover_sage
  ].freeze

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

    flow = ActivityFlow.create_from_invitation(
      invitation,
      cookies.permanent.signed[:device_id] || SecureRandom.uuid,
      overrides.to_h.symbolize_keys
    )

    reporting_window_months = user_data[:reporting_window_months] || overrides[:reporting_window_months]
    flow.update!(reporting_window_months: reporting_window_months) if reporting_window_months

    if overrides[:reporting_window_start].present?
      flow.shift_reporting_window_start!(overrides[:reporting_window_start])
    end

    identity = Identity.find_or_create_by!(
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
    create_fake_enrollment_terms(education_activity, user_data, reporting_window)
    education_activity.update!(
      data_source: EducationActivity.data_source_from_nsc_results(education_activity.nsc_enrollment_terms)
    )

    set_flow_session(flow.id, :activity)
    activities_flow_root_url(**launcher_url_options)
  end

  def create_fake_enrollment_terms(education_activity, user_data, reporting_window)
    fake_terms_for_user_data(user_data).each do |term_data|
      term_begin, term_end = if term_data[:term_type].present?
                               fake_term_dates_for_type(term_data, reporting_window)
                             else
                               [ reporting_window.begin, reporting_window.end ]
                             end

      education_activity.nsc_enrollment_terms.create!(
        school_name: term_data[:school_name],
        first_name: user_data[:first_name],
        last_name: user_data[:last_name],
        enrollment_status: term_data[:enrollment_status],
        term_begin: term_begin,
        term_end: term_end
      )
    end
  end

  def fake_terms_for_user_data(user_data)
    if user_data[:terms]
      total_terms = user_data[:terms].length

      return user_data[:terms].each_with_index.map do |term, index|
        term.reverse_merge(
          term_type: :reporting_window_segmented,
          term_index: index,
          total_terms: total_terms
        )
      end
    end

    enrollments = user_data[:enrollments] || user_data[:school_names].map do |school_name|
      { school_name: school_name, enrollment_status: :less_than_half_time }
    end

    enrollments
  end

  def fake_term_dates_for_type(term_data, reporting_window)
    year = reporting_window.begin.year

    case term_data[:term_type].to_sym
    when :reporting_window_segmented
      total_days = (reporting_window.end - reporting_window.begin).to_i
      days_per_term = total_days / term_data[:total_terms]
      term_begin = reporting_window.begin + (term_data[:term_index] * days_per_term)
      term_end = if term_data[:term_index] == term_data[:total_terms] - 1
                   reporting_window.end
                 else
                   reporting_window.begin + ((term_data[:term_index] + 1) * days_per_term)
                 end
      [ term_begin, term_end ]
    when :qualifying_spring
      [ Date.new(year, 3, 1), Date.new(year, 6, 15) ]
    when :summer_less_than_half_time
      [ Date.new(year, 7, 1), Date.new(year, 8, 15) ]
    else
      raise ArgumentError, "Unknown fake term type: #{term_data[:term_type]}"
    end
  end
end
