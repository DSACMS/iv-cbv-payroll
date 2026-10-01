require "rails_helper"

RSpec.describe Transmitters::ActivityJsonTransmitter do
  include NscApiHelper

  let(:current_agency) { Rails.application.config.client_agencies["sandbox"] }
  let(:api_url) { "http://fake-state.api.gov/api/v1/ce-activity-report" }
  let(:cbv_applicant) do
    create(:cbv_applicant, client_agency_id: "sandbox", first_name: persona[:first_name], middle_name: nil,
      last_name: persona[:last_name], date_of_birth: persona[:date_of_birth], case_number: "EDUCATION-SAMPLE")
  end
  let(:identity) do
    create(:identity, activity_flows_count: 0, first_name: persona[:first_name],
      last_name: persona[:last_name], date_of_birth: persona[:date_of_birth])
  end
  let(:invitation) { create(:activity_flow_invitation, reference_id: "demo-#{scenario_key}") }
  let(:activity_flow) do
    create(:activity_flow, cbv_applicant: cbv_applicant, identity: identity, activity_flow_invitation: invitation,
      volunteering_activities_count: 0, job_training_activities_count: 0, education_activities_count: 0,
      employment_activities_count: 0, created_at: Time.zone.parse("2026-09-01 12:00:00"),
      completed_at: Time.zone.parse("2026-09-01 14:00:00"), reporting_window_months: 6,
      confirmation_code: "EDUCATION-SAMPLE")
  end
  let(:education_activity) { create(:education_activity, activity_flow: activity_flow, draft: true, additional_comments: nil) }
  let(:transmitter) { described_class.new(activity_flow, current_agency) }
  let(:payload) { JSON.parse(transmitter.payload) }
  let(:education_entries) { payload.dig("ce_report", "activities", "education").values.flatten }

  before do
    create(:user, :with_access_token, client_agency_id: "sandbox", is_service_account: true)
    stub_client_agency_config_value("sandbox", :activity_transmission_method_configuration, { "json_api_url" => api_url })
  end

  shared_examples "an education report" do |expected_data_source|
    it "delivers an education report" do
      if expected_data_source
        expect(education_entries).to be_present
        expect(education_entries).to all(include("type" => "education", "data_source" => expected_data_source))
      else
        expect(payload.dig("ce_report", "activities", "education")).to eq({})
      end

      request = stub_request(:post, api_url).with(body: transmitter.payload).to_return(status: 200)
      expect(transmitter.deliver).to eq("ok")
      expect(request).to have_been_requested

      path = Rails.root.join("tmp/ce-education-reports", "#{scenario_key}.json")
      FileUtils.mkdir_p(path.dirname)
      path.write(JSON.pretty_generate(payload) + "\n")
    end
  end

  Launcher::FakeNscScenarios::USER_PROFILES.each do |profile|
    context "for #{profile.first_name} #{profile.last_name}" do
      let(:scenario_key) { profile.scenario_key }
      let(:persona) { { first_name: profile.first_name, last_name: profile.last_name, date_of_birth: profile.date_of_birth } }

      before do
        Launcher::FakeNscDataFetcherService.new(education_activity: education_activity).fetch
        complete_nsc_education!
      end

      it_behaves_like "an education report", %w[partial_enrollment_casey summer_term_carryover_sage spring_fall_no_summer_morgan]
        .include?(profile.scenario_key) ? "nsc" : "self_attested"
    end
  end

  LauncherController::TEST_SCENARIOS.each do |key, user_data|
    context "for #{user_data[:first_name]} #{user_data[:last_name]}" do
      let(:scenario_key) { key }
      let(:persona) { user_data }

      before do
        nsc_stub_token_request
        fixture = { "rick" => "rick_banas", "dominique" => "dominique_ricardo" }.fetch(key, key)
        nsc_stub_request_education_search_response(fixture)
        Launcher::NscForwardDatingService.new(education_activity: education_activity).fetch
        complete_nsc_education! unless education_activity.sync_no_enrollments?
      end

      it_behaves_like "an education report", {
        "rick" => "nsc", "lynette" => "self_attested", "dominique" => nil, "linda" => nil
      }.fetch(key)
    end
  end

  context "with fully self-attested education" do
    let(:scenario_key) { "fully_self_attested" }
    let(:persona) { { first_name: "Jane", last_name: "Example", date_of_birth: Date.new(1990, 4, 15) } }

    before { add_manual_education! }

    it_behaves_like "an education report", "self_attested"
  end

  def complete_nsc_education!
    if education_activity.partially_self_attested?
      education_activity.less_than_half_time_terms_in_reporting_window.each do |term|
        term.update!(credit_hours: 3)
      end
    end
    education_activity.publish!
  end

  def add_manual_education!
    education = create(:education_activity, activity_flow: activity_flow, data_source: :fully_self_attested,
      school_name: "Example Community College", contact_email: "registrar@example.org", additional_comments: nil)
    activity_flow.reporting_months.each do |month|
      create(:education_activity_month, education_activity: education, month: month, hours: 3.5)
    end
  end
end
