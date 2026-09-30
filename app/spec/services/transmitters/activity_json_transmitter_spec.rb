require "rails_helper"
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
    let(:schema_path) { Rails.root.parent.join("docs/api/schemas/ce-activity-report-2026-09-01.json") }
    let(:sample_path) { Rails.root.parent.join("docs/api/samples/ce-activity-report.json") }

    before { populate_activities! }

    it "matches the published CE activity report JSON Schema" do
      errors = JSONSchemer.schema(JSON.parse(schema_path.read))
        .validate(JSON.parse(transmitter.payload))
        .map { |error| error.slice("data_pointer", "type", "error") }

      expect(errors).to eq([])
    end

    it "still matches the schema when an unenforced field is blank" do
      blank = activity_flow.volunteering_activities.new(organization_name: "", draft: true)
      blank.save!
      blank.publish!
      create(:volunteering_activity_month, volunteering_activity: blank,
        month: activity_flow.reporting_months.first, hours: 5)

      errors = JSONSchemer.schema(JSON.parse(schema_path.read))
        .validate(JSON.parse(transmitter.payload))
        .map { |error| error.slice("data_pointer", "type", "error") }

      expect(errors).to eq([])
    end

    it "matches the published sample report shared with agencies" do
      payload = JSON.parse(transmitter.payload)
      sample = JSON.parse(sample_path.read)
      payload_document_ids = payload.dig("ce_report", "documents").map { |document| document["document_id"] }
      sample_document_ids = sample.dig("ce_report", "documents").map { |document| document["document_id"] }
      document_id_mapping = sample_document_ids.zip(payload_document_ids).to_h

      sample["ce_report"]["documents"].each do |document|
        document["document_id"] = document_id_mapping.fetch(document["document_id"])
      end
      sample["ce_report"]["activities"].each_value do |months|
        months.each_value do |entries|
          entries.each do |entry|
            entry["document_ids"].map! { |id| document_id_mapping.fetch(id) }
          end
        end
      end

      expect(payload).to eq(sample)
    end
  end

  describe "employment sample reports" do
    include ArgyleApiHelper

    let(:schema) { JSONSchemer.schema(JSON.parse(Rails.root.parent.join("docs/api/schemas/ce-activity-report-2026-09-01.json").read)) }
    let(:samples_path) { Rails.root.parent.join("docs/api/samples/ce-employment-reports.json") }

    before do
      activity_flow.update!(created_at: Time.zone.parse("2025-04-11 12:00:00"),
        completed_at: Time.zone.parse("2025-04-11 14:00:00"), reporting_window_months: 2)
    end

    def verify_and_export_sample(name)
      expect(Rails.logger).not_to receive(:error)
      payload = JSON.parse(transmitter.payload)
      errors = schema.validate(payload).map { |error| error.slice("data_pointer", "type", "error") }
      expect(errors).to eq([])
      request = stub_request(:post, api_url).with(body: transmitter.payload).to_return(status: 200)
      expect(transmitter.deliver).to eq("ok")
      expect(request).to have_been_requested

      # Attachment IDs vary between runs; keep the public synthetic examples stable.
      ids = payload.dig("ce_report", "documents").each_with_index.to_h do |document, index|
        [ document.fetch("document_id"), "DOC-#{index + 1}" ]
      end
      payload.dig("ce_report", "documents").each { |document| document["document_id"] = ids.fetch(document["document_id"]) }
      payload.dig("ce_report", "activities").each_value do |months|
        months.each_value do |entries|
          entries.each { |entry| entry["document_ids"].map! { |id| ids.fetch(id) } }
        end
      end
      if ENV["UPDATE_CE_EMPLOYMENT_SAMPLES"] == "1"
        samples = samples_path.exist? ? JSON.parse(samples_path.read) : {}
        samples[name] = payload
        samples_path.write(JSON.pretty_generate(samples.sort.to_h) + "\n")
      end
      expect(payload).to eq(JSON.parse(samples_path.read).fetch(name))
      payload
    end

    %w[bob joe kim].each do |persona|
      it "transmits and exports #{persona}'s Argyle sandbox payroll data" do
        account_id = argyle_load_relative_json_file(persona, "request_identity.json").fetch("results").first.fetch("account")
        create(:payroll_account, :argyle_fully_synced, flow: activity_flow, aggregator_account_id: account_id)
        argyle_stub_request_identities_response(persona)
        argyle_stub_request_account_response(persona)
        # Only the recorded page is needed for this review period.
        paystubs = argyle_load_relative_json_file(persona, "request_paystubs.json").merge("next" => nil)
        stub_request(:get, %r{#{Aggregators::Sdk::ArgyleService::PAYSTUBS_ENDPOINT}})
          .with(query: hash_including("account" => account_id, "from_start_date" => "2025-02-01", "to_start_date" => "2025-03-31"))
          .to_return(status: 200, body: paystubs.to_json, headers: { "Content-Type" => "application/json" })
        argyle_stub_request_gigs_response(persona == "joe" ? "empty" : persona)

        payload = verify_and_export_sample("argyle_#{persona}")
        employment = payload.dig("ce_report", "activities", "employment")
        expect(employment.keys).to eq(%w[2025-02 2025-03])
        employment.each do |month, entries|
          expect(entries.sole["data_source"]).to eq("validated")
          expect(entries.sole["paystubs"]).not_to be_empty
          expect(entries.sole["paystubs"].map { |paystub| paystub["pay_date"][0, 7] }.uniq).to eq([ month ])
        end
      end
    end

    it "transmits and exports mixed Pinwheel, self-employed, and unpaid work" do
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

      payload = verify_and_export_sample("mixed_employment")
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
