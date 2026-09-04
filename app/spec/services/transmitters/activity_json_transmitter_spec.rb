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
      expect(JSON.parse(transmitter.payload)).to eq(JSON.parse(sample_path.read))
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
