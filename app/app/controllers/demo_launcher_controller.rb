class DemoLauncherController < ApplicationController
  helper_method :session_timeout_enabled?

  def show
    set_flow_session(nil, :activity)
  end

  def create
    client_agency_id = params[:client_agency_id]
    launch_type = params[:launch_type]
    nsc_test_user = params[:nsc_test_user]

    overrides = params.permit(:reporting_window, :reporting_window_months, :demo_timeout).select { |_, v| v.present? }

    url = if launch_type == "generic"
            build_generic_url(client_agency_id, overrides)
          elsif nsc_test_user.present?
            build_nsc_test_user_url(nsc_test_user, client_agency_id, overrides)
          else
            build_tokenized_url(client_agency_id, overrides)
          end

    redirect_to url, allow_other_host: true
  end

  private

  def session_timeout_enabled?
    false
  end

  def build_generic_url(client_agency_id, overrides)
    Rails.application.routes.url_helpers.activities_flow_new_url(
      client_agency_id: client_agency_id,
      host: request.host_with_port,
      protocol: request.protocol,
      **overrides
    )
  end

  def build_tokenized_url(client_agency_id, overrides)
    invitation = ActivityFlowInvitation.create!(
      client_agency_id: client_agency_id,
      reference_id: "demo-#{SecureRandom.hex(4)}"
    )
    invitation.to_url(
      host: request.host_with_port,
      protocol: request.protocol,
      **overrides
    )
  end

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
      host: request.host_with_port,
      protocol: request.protocol,
      **overrides
    )
  end
end
