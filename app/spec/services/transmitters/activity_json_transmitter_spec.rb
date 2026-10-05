require "swagger_helper"
require "json_schemer"

RSpec.describe Transmitters::ActivityJsonTransmitter do
  let(:api_url) { "http://fake-state.api.gov/api/v1/ce-activity-report" }
  let(:activity_transmission_method_configuration) { { "json_api_url" => api_url } }
  let(:cbv_applicant) do
    create(:cbv_applicant, client_agency_id: "sandbox", first_name: "Jane", middle_name: "A", last_name: "Doe",
      case_number: "CASE-2026-00987", date_of_birth: Date.new(1990, 4, 15))
  end
  let(:activity_flow) do
    create(
      :activity_flow,
      cbv_applicant: cbv_applicant,
      volunteering_activities_count: 0,
      job_training_activities_count: 0,
      education_activities_count: 0,
      employment_activities_count: 0,
      with_identity: false,
      created_at: Time.zone.parse("2026-08-11 12:00:00"),
      completed_at: Time.zone.parse("2026-08-11 14:00:00"),
      confirmation_code: "SANDBOX123"
    )
  end
  let(:current_agency) do
    instance_double(
      ClientAgencyConfig::ClientAgency,
      id: "sandbox",
      activity_transmission_method_configuration: activity_transmission_method_configuration
    )
  end
  let(:transmitter) { described_class.new(activity_flow, current_agency) }
  let(:document) { JSONSchemer.openapi(JSON.parse(RSpec.configuration.openapi_specs.fetch("openapi.json").to_json)) }
  let(:schema) { document.schema("CeActivityReport") }

  let!(:service_user) { create(:user, client_agency_id: "sandbox", is_service_account: true) }
  let!(:api_token) { create(:api_access_token, user: service_user) }

  before do
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:error)
  end

  def populate_activities!
    volunteering = create(
      :volunteering_activity,
      activity_flow: activity_flow,
      organization_name: "Local Food Bank",
      street_address: "1 Main St",
      city: "New Orleans",
      state: "LA",
      zip_code: "70112",
      coordinator_name: "Jane Smith",
      coordinator_email: "jane@example.org",
      coordinator_phone_number: "5045551234"
    )
    activity_flow.reporting_months.each do |month|
      create(:volunteering_activity_month, volunteering_activity: volunteering, month: month, hours: 40)
    end

    job_training = create(
      :job_training_activity,
      activity_flow: activity_flow,
      organization_name: "Goodwill",
      program_name: "WIOA",
      contact_name: "Casey Doe",
      contact_email: "casey@example.org",
      contact_phone_number: "5045555678"
    )
    activity_flow.reporting_months.each do |month|
      create(:job_training_activity_month, job_training_activity: job_training, month: month, hours: 20)
    end

    job_training.document_uploads.attach(
      io: StringIO.new("synthetic document"),
      filename: "WIOA Participation Letter.pdf",
      content_type: "application/pdf"
    )
  end

  describe "#payload" do
    before { populate_activities! }

    it "matches the published CE activity report OpenAPI model" do
      errors = schema.validate(JSON.parse(transmitter.payload))
        .map { |error| error.slice("data_pointer", "type", "error") }

      expect(errors).to eq([])
    end

    it "still matches the schema when an unenforced field is blank" do
      blank = activity_flow.volunteering_activities.new(organization_name: "", draft: true)
      blank.save!
      blank.publish!
      create(:volunteering_activity_month, volunteering_activity: blank,
        month: activity_flow.reporting_months.first, hours: 5)

      errors = schema.validate(JSON.parse(transmitter.payload))
        .map { |error| error.slice("data_pointer", "type", "error") }

      expect(errors).to eq([])
    end

    it "omits extended_attributes throughout the report" do
      expect(transmitter.payload).not_to include('"extended_attributes"')
    end
  end

  describe "employment OpenAPI examples" do
    include ArgyleApiHelper

    before do
      activity_flow.update!(created_at: Time.zone.parse("2025-04-11 12:00:00"),
        completed_at: Time.zone.parse("2025-04-11 14:00:00"), reporting_window_months: 2)
    end

    def verify_employment_report
      expect(Rails.logger).not_to receive(:error)
      payload = JSON.parse(transmitter.payload)
      errors = schema.validate(payload).map { |error| error.slice("data_pointer", "type", "error") }
      expect(errors).to eq([])
      expect(transmitter.payload).not_to include('"extended_attributes"')
      request = stub_request(:post, api_url).with(body: transmitter.payload).to_return(status: 200)
      expect(transmitter.deliver).to eq("ok")
      expect(request).to have_been_requested

      payload
    end

    it "validates and transmits bob's Argyle sandbox payroll data" do
      account_id = argyle_load_relative_json_file("bob", "request_identity.json").fetch("results").first.fetch("account")
      create(:payroll_account, :argyle_fully_synced, flow: activity_flow, aggregator_account_id: account_id)
      argyle_stub_request_identities_response("bob")
      argyle_stub_request_account_response("bob")
      # Only the recorded page is needed for this review period.
      paystubs = argyle_load_relative_json_file("bob", "request_paystubs.json").merge("next" => nil)
      stub_request(:get, %r{#{Aggregators::Sdk::ArgyleService::PAYSTUBS_ENDPOINT}})
        .with(query: hash_including("account" => account_id, "from_start_date" => "2025-02-01", "to_start_date" => "2025-03-31"))
        .to_return(status: 200, body: paystubs.to_json, headers: { "Content-Type" => "application/json" })
      argyle_stub_request_gigs_response("bob")

      payload = verify_employment_report
      employment = payload.dig("ce_report", "activities", "employment")
      expect(employment.keys).to eq(%w[2025-02 2025-03])
      employment.each do |month, entries|
        expect(entries.sole["data_source"]).to eq("validated")
        expect(entries.sole["paystubs"]).not_to be_empty
        expect(entries.sole["paystubs"].map { |paystub| paystub["pay_date"][0, 7] }.uniq).to eq([ month ])
      end
    end

    it "validates and transmits joe's Argyle sandbox payroll data" do
      account_id = argyle_load_relative_json_file("joe", "request_identity.json").fetch("results").first.fetch("account")
      create(:payroll_account, :argyle_fully_synced, flow: activity_flow, aggregator_account_id: account_id)
      argyle_stub_request_identities_response("joe")
      argyle_stub_request_account_response("joe")
      # Only the recorded page is needed for this review period.
      paystubs = argyle_load_relative_json_file("joe", "request_paystubs.json").merge("next" => nil)
      stub_request(:get, %r{#{Aggregators::Sdk::ArgyleService::PAYSTUBS_ENDPOINT}})
        .with(query: hash_including("account" => account_id, "from_start_date" => "2025-02-01", "to_start_date" => "2025-03-31"))
        .to_return(status: 200, body: paystubs.to_json, headers: { "Content-Type" => "application/json" })
      argyle_stub_request_gigs_response("empty")

      payload = verify_employment_report
      employment = payload.dig("ce_report", "activities", "employment")
      expect(employment.keys).to eq(%w[2025-02 2025-03])
      employment.each do |month, entries|
        expect(entries.sole["data_source"]).to eq("validated")
        expect(entries.sole["paystubs"]).not_to be_empty
        expect(entries.sole["paystubs"].map { |paystub| paystub["pay_date"][0, 7] }.uniq).to eq([ month ])
      end
    end

    it "validates and transmits kim's Argyle sandbox payroll data" do
      account_id = argyle_load_relative_json_file("kim", "request_identity.json").fetch("results").first.fetch("account")
      create(:payroll_account, :argyle_fully_synced, flow: activity_flow, aggregator_account_id: account_id)
      argyle_stub_request_identities_response("kim")
      argyle_stub_request_account_response("kim")
      # Only the recorded page is needed for this review period.
      paystubs = argyle_load_relative_json_file("kim", "request_paystubs.json").merge("next" => nil)
      stub_request(:get, %r{#{Aggregators::Sdk::ArgyleService::PAYSTUBS_ENDPOINT}})
        .with(query: hash_including("account" => account_id, "from_start_date" => "2025-02-01", "to_start_date" => "2025-03-31"))
        .to_return(status: 200, body: paystubs.to_json, headers: { "Content-Type" => "application/json" })
      argyle_stub_request_gigs_response("kim")

      payload = verify_employment_report
      employment = payload.dig("ce_report", "activities", "employment")
      expect(employment.keys).to eq(%w[2025-02 2025-03])
      employment.each do |month, entries|
        expect(entries.sole["data_source"]).to eq("validated")
        expect(entries.sole["paystubs"]).not_to be_empty
        expect(entries.sole["paystubs"].map { |paystub| paystub["pay_date"][0, 7] }.uniq).to eq([ month ])
      end
    end

    it "publishes a complete CE model example with mixed employment" do
      account = create(:payroll_account, :pinwheel_fully_synced, flow: activity_flow, aggregator_account_id: "account1")
      payroll_report = build(:pinwheel_report, :hydrated, payroll_accounts: [ account ], has_fetched: true)
      payroll_report.incomes.first.compensation_unit = "hourly"
      payroll_report.paystubs.first.pay_date = "2025-03-01"
      payroll_report.paystubs.first.pay_period_start = "2025-02-15"
      payroll_report.paystubs.first.pay_period_end = "2025-02-28"
      fetcher = instance_double(AggregatorReportFetcher, report_for_payroll_account: payroll_report)
      allow(AggregatorReportFetcher).to receive(:new).with(activity_flow).and_return(fetcher)

      self_employed = create(:employment_activity, activity_flow: activity_flow, employer_name: "Side Gig LLC", is_self_employed: true)
      unpaid = create(:employment_activity, activity_flow: activity_flow, employer_name: "Work For Free LLC", compensation_type: :unpaid_or_in_kind)
      create(:employment_activity_month, employment_activity: self_employed, month: Date.new(2025, 3, 1), hours: 12.75, gross_income: 123.45)
      create(:employment_activity_month, employment_activity: unpaid, month: Date.new(2025, 3, 1), hours: 20, gross_income: 0)
      self_employed.document_uploads.attach(io: StringIO.new("Synthetic income statement"), filename: "Income statement.pdf", content_type: "application/pdf")

      populate_activities!
      payload = verify_employment_report
      RSpec.configuration.openapi_specs.fetch("openapi.json")[:components][:schemas][:CeActivityReport][:example] = payload
      expect(payload.dig("ce_report", "activities", "employment", "2025-03").map { |entry| entry["employment_type"] })
        .to eq(%w[self_employed unpaid gig])
    end

    it "does not post a partial report when a payroll fetch fails" do
      create(:payroll_account, :pinwheel_fully_synced, flow: activity_flow)
      failed_report = instance_double(Aggregators::AggregatorReports::PinwheelReport, has_fetched?: false)
      fetcher = instance_double(AggregatorReportFetcher, report_for_payroll_account: failed_report)
      allow(AggregatorReportFetcher).to receive(:new).with(activity_flow).and_return(fetcher)
      request = stub_request(:post, api_url).to_return(status: 200)

      expect { transmitter.deliver }.to raise_error(ActivityReportSerializer::PayrollReportError)
      expect(request).not_to have_been_requested
    end
  end

  describe "#deliver" do
    it "posts the serialized report and returns ok" do
      request = stub_request(:post, api_url)
        .with(headers: { "Content-Type" => "application/json", "X-IVAAS-Confirmation-Code" => "SANDBOX123" })
        .to_return(status: 200, body: '{"status": "received"}')

      expect(transmitter.deliver).to eq("ok")
      expect(request).to have_been_requested
    end

    it "signs the request body with the agency's API key" do
      stub_request(:post, api_url).to_return(status: 200, body: '{"status": "received"}')

      expect(JsonApiSignature).to receive(:generate)
        .with(a_string_including("SANDBOX123"), anything, api_token.access_token)
        .and_return("mock-signature")

      transmitter.deliver

      expect(WebMock).to have_requested(:post, api_url)
        .with(headers: { "X-IVAAS-Signature" => "mock-signature" })
    end

    it "sends configured custom headers" do
      allow(current_agency).to receive(:activity_transmission_method_configuration)
        .and_return(activity_transmission_method_configuration.merge(
          "custom_headers" => { "X-Gateway-APIKey" => "test-key" }
        ))
      request = stub_request(:post, api_url)
        .with(headers: { "X-Gateway-APIKey" => "test-key" })
        .to_return(status: 200, body: '{"status": "received"}')

      transmitter.deliver

      expect(request).to have_been_requested
    end

    it "logs the request destination and response status with duration" do
      stub_request(:post, api_url).to_return(status: 200, body: '{"status": "received"}')

      expect(Rails.logger).to receive(:info)
        .with("Sending activity JSON transmission to #{api_url}")
        .ordered
      expect(Rails.logger).to receive(:info)
        .with(a_string_matching(
          %r{\AActivity JSON transmission response from #{Regexp.escape(api_url)}: status=200 duration=\d+\.\d{3}s\z}
        ))
        .ordered

      transmitter.deliver
    end

    it "raises a transmitter error when the agency rejects the report" do
      stub_request(:post, api_url).to_return(status: [ 500, "Internal Server Error" ], body: "Internal Server Error")

      expect { transmitter.deliver }
        .to raise_error(described_class::ActivityJsonTransmitterError, /Unexpected response from agency/)

      expect(Rails.logger).to have_received(:error)
        .with(/Unexpected response from agency: code=500 message=Internal Server Error/)
      expect(Rails.logger).to have_received(:error).with("Error response body: Internal Server Error")
    end

    it "raises a silenceable error for configured response codes" do
      allow(current_agency).to receive(:activity_transmission_method_configuration)
        .and_return(activity_transmission_method_configuration.merge("silently_retry_error_codes" => [ 408 ]))
      stub_request(:post, api_url).to_return(status: [ 408, "Request Timeout" ], body: "Request Timeout")

      expect { transmitter.deliver }
        .to raise_error(ApplicationJob::SilencedError, /code=408 message=Request Timeout/)
    end
  end
end
