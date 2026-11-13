require "rails_helper"

RSpec.describe ActivityFlowTransmitterJob, type: :job do
  let(:transmission_method) { "json" }
  let(:api_url) { "https://la.example.gov/reports" }
  let(:documents_api_url) { "https://la.example.gov/documents" }
  let(:response_status) { 200 }
  let(:agency_config) { ClientAgencyConfig.new(Rails.root.join("config/client-agency-config.yml")) }
  let(:activity_flow) do
    create(:activity_flow,
      cbv_applicant: create(:cbv_applicant, :la_ldh),
      volunteering_activities_count: 0,
      job_training_activities_count: 0,
      education_activities_count: 0,
      employment_activities_count: 0,
      completed_at: Time.current)
  end
  let(:gateway_headers) do
    { "X-Gateway-APIKey" => "synthetic-gateway-key", "AccountCode" => "00123" }
  end
  let(:request_stub) do
    stub_request(:post, api_url).with(headers: gateway_headers).to_return(status: response_status)
  end

  around do |example|
    ClimateControl.modify(
      LA_LDH_ACTIVITY_FLOW_TRANSMISSION_METHOD: transmission_method,
      LA_LDH_ACTIVITY_JSON_API_URL: "https://la.example.gov/reports",
      LA_LDH_ACTIVITY_DOCUMENTS_API_URL: documents_api_url,
      LA_LDH_ACTIVITY_APIKEY: "synthetic-gateway-key",
      LA_LDH_ACTIVITY_ACCOUNTCODE: "00123"
    ) { example.run }
  end

  before do
    allow(Rails.application.config).to receive(:client_agencies).and_return(agency_config)
    allow(User).to receive(:api_key_for_agency).with("la_ldh").and_return("synthetic-signing-key")
    request_stub
  end

  it "delivers the report JSON using LA's configured URL and gateway headers" do
    expect { described_class.perform_now(activity_flow.id) }
      .to change { activity_flow.reload.transmitted_at }.from(nil)

    expect(request_stub).to have_been_requested.once
  end

  context "when the activity delivery method is not set" do
    let(:transmission_method) { nil }

    it "skips delivery using the configured none default" do
      expect { described_class.new.perform(activity_flow.id) }
        .not_to change { activity_flow.reload.transmitted_at }

      expect(request_stub).not_to have_been_requested
    end
  end

  context "when LA returns 403" do
    let(:response_status) { 403 }

    it "raises a silenced error" do
      expect { described_class.new.perform(activity_flow.id) }
        .to raise_error(ApplicationJob::SilencedError, /code=403/)
    end
  end

  context "when LA returns 408" do
    let(:response_status) { 408 }

    it "raises a silenced error" do
      expect { described_class.new.perform(activity_flow.id) }
        .to raise_error(ApplicationJob::SilencedError, /code=408/)
    end
  end

  context "when LA returns 502" do
    let(:response_status) { 502 }

    around do |example|
      Timecop.freeze(Time.current, &example)
    end

    it "raises a silenced error" do
      expect { described_class.new.perform(activity_flow.id) }
        .to raise_error(ApplicationJob::SilencedError, /code=502/)
    end

    it "retries on the normal schedule without marking the flow transmitted" do
      expect { described_class.perform_now(activity_flow.id) }
        .to have_enqueued_job(described_class).with(activity_flow.id).at(5.minutes.from_now)

      expect(activity_flow.reload.transmitted_at).to be_nil
    end
  end

  context "when LA returns an error outside the silenced list" do
    let(:response_status) { 500 }

    it "raises the regular transmitter error" do
      expect { described_class.new.perform(activity_flow.id) }
        .to raise_error(Transmitters::ActivityJsonTransmitter::ActivityJsonTransmitterError, /code=500/)
    end
  end

  context "with document delivery enabled" do
    let(:transmission_method) { "http" }
    let(:api_url) { documents_api_url }
    let(:processed_download_service) { instance_double(ProcessedDownloadService) }

    before do
      activity = create(:volunteering_activity, activity_flow: activity_flow)
      activity.document_uploads.attach(
        io: StringIO.new("synthetic document"), filename: "timesheet.pdf", content_type: "application/pdf"
      )
      allow(ProcessedDownloadService).to receive(:new).and_return(processed_download_service)
      allow(processed_download_service).to receive(:download_file) do |_key, path|
        File.binwrite(path, "synthetic document")
      end
    end

    it "delivers the document using LA's configured URL and gateway headers" do
      expect { described_class.perform_now(activity_flow.id) }
        .to change { activity_flow.reload.transmitted_at }.from(nil)

      expect(request_stub).to have_been_requested.once
    end

    context "when LA returns 403" do
      let(:response_status) { 403 }

      it "raises a silenced error using the activity configuration" do
        expect { described_class.new.perform(activity_flow.id) }
          .to raise_error(ApplicationJob::SilencedError, /code=403/)
      end
    end
  end
end
