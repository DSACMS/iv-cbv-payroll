require "rails_helper"

RSpec.describe CaseworkerMailerFallbackService do
  let(:service) { described_class.new }
  let(:la_ldh_applicant) { create(:cbv_applicant, :la_ldh) }
  let(:cbv_flow) { create(:cbv_flow, cbv_applicant: la_ldh_applicant) }
  let(:caseworker_fallback_email) { Rails.application.config.client_agencies["la_ldh"].caseworker_fallback_email }
  let(:mock_report) { instance_double(Aggregators::AggregatorReports::AggregatorReport) }
  let(:mock_mail) { instance_double(ActionMailer::MessageDelivery, deliver_now: nil) }

  def create_failed_execution(flow, error: "Some error")
    job = SolidQueue::Job.create!(
      class_name: "CaseWorkerTransmitterJob",
      arguments: { "job_class" => "CaseWorkerTransmitterJob", "arguments" => [ flow.id ] },
      queue_name: "default"
    )
    SolidQueue::FailedExecution.create!(job: job, error: error)
  end

  before do
    allow(AggregatorReportFetcher).to receive(:new).and_return(double(report: mock_report))
    allow(CaseworkerMailer).to receive(:with).and_return(double(summary_email: mock_mail))
  end

  describe "#deliver_all" do
    context "when there are no failed CaseWorkerTransmitterJob executions" do
      it "returns sent: 0 and empty skipped list" do
        result = service.deliver_all
        expect(result).to eq({ sent: 0, skipped: [], warnings: [] })
      end
    end

    context "when the cbv_flow referenced by the job does not exist" do
      before do
        job = SolidQueue::Job.create!(
          class_name: "CaseWorkerTransmitterJob",
          arguments: { "job_class" => "CaseWorkerTransmitterJob", "arguments" => [ 999_999_999 ] },
          queue_name: "default"
        )
        SolidQueue::FailedExecution.create!(job: job, error: "some error")
      end

      it "skips and reports the cbv_flow as not found" do
        result = service.deliver_all
        expect(result[:sent]).to eq(0)
        expect(result[:skipped].first).to include("CbvFlow record not found")
      end
    end

    context "when the cbv_flow has already been transmitted" do
      before do
        cbv_flow.update!(transmitted_at: 1.hour.ago)
        create_failed_execution(cbv_flow)
      end

      it "skips and reports it as already transmitted" do
        result = service.deliver_all
        expect(result[:sent]).to eq(0)
        expect(result[:skipped].first).to include("already transmitted")
      end
    end

    context "when the applicant has been redacted" do
      before do
        cbv_flow.cbv_applicant.redact!
        create_failed_execution(cbv_flow)
      end

      it "sends the email and returns a warning" do
        result = service.deliver_all
        expect(result[:sent]).to eq(1)
        expect(result[:skipped]).to eq([])
        expect(result[:warnings].first).to include("applicant is redacted")
        expect(mock_mail).to have_received(:deliver_now)
      end
    end

    context "when the agency has no caseworker_fallback_email" do
      let(:sandbox_flow) { create(:cbv_flow) }

      before { create_failed_execution(sandbox_flow) }

      it "skips and reports that no fallback email is configured" do
        result = service.deliver_all
        expect(result[:sent]).to eq(0)
        expect(result[:skipped].first).to include("no caseworker_fallback_email configured")
      end
    end

    context "when all conditions are met" do
      before { create_failed_execution(cbv_flow) }

      it "sends the email to the agency fallback address" do
        service.deliver_all
        expect(CaseworkerMailer).to have_received(:with).with(
          email_address: caseworker_fallback_email,
          cbv_flow: cbv_flow,
          aggregator_report: mock_report
        )
        expect(mock_mail).to have_received(:deliver_now)
      end

      it "marks the flow as transmitted" do
        expect { service.deliver_all }
          .to change { cbv_flow.reload.transmitted_at }.from(nil)
      end

      it "destroys the failed execution" do
        expect { service.deliver_all }
          .to change(SolidQueue::FailedExecution, :count).by(-1)
      end

      it "returns sent: 1, skipped: []" do
        result = service.deliver_all
        expect(result).to eq({ sent: 1, skipped: [], warnings: [] })
      end
    end

    context "with filter_name: la_ldh_schema_error" do
      let(:schema_error) { "API Specification validation failed: response body did not match the schema" }
      let(:other_error) { "Connection refused - connect(2) for localhost" }
      let(:other_applicant) { create(:cbv_applicant, :la_ldh) }
      let(:other_flow) { create(:cbv_flow, cbv_applicant: other_applicant) }

      before do
        create_failed_execution(cbv_flow, error: schema_error)
        create_failed_execution(other_flow, error: other_error)
      end

      it "sends only for schema validation failures, skipping other errors" do
        result = service.deliver_all(filter_name: "la_ldh_schema_error")
        expect(result[:sent]).to eq(1)
        expect(mock_mail).to have_received(:deliver_now).once
      end
    end
  end

  describe "#preview" do
    context "when there are no failed CaseWorkerTransmitterJob executions" do
      it "returns zero count and empty entries" do
        result = service.preview

        expect(result).to eq({ count: 0, entries: [] })
      end
    end

    context "when a failed execution references an existing cbv_flow" do
      let(:error) { "API Specification validation failed: response body did not match the schema" }

      before { create_failed_execution(cbv_flow, error: error) }

      it "returns the details needed by the preview rake task" do
        result = service.preview

        expect(result[:count]).to eq(1)
        expect(result[:entries].first).to include(
          cbv_flow_id: cbv_flow.id,
          agency_id: "la_ldh",
          fallback_email: caseworker_fallback_email,
          case_number: cbv_flow.cbv_applicant.case_number,
          transmitted: "not yet sent",
          error: error
        )
      end
    end

    context "when a failed execution references a redacted applicant" do
      before do
        cbv_flow.cbv_applicant.redact!
        create_failed_execution(cbv_flow)
      end

      it "returns a sendable entry with a warning" do
        result = service.preview

        expect(result[:entries].first).to include(
          cbv_flow_id: cbv_flow.id,
          status: :sendable,
          warning: "applicant is redacted"
        )
      end
    end

    context "when a failed execution references a missing cbv_flow" do
      before do
        job = SolidQueue::Job.create!(
          class_name: "CaseWorkerTransmitterJob",
          arguments: { "job_class" => "CaseWorkerTransmitterJob", "arguments" => [ 999_999_999 ] },
          queue_name: "default"
        )
        SolidQueue::FailedExecution.create!(job: job, error: "some error")
      end

      it "returns a skipped preview entry with the reason" do
        result = service.preview

        expect(result[:entries].first).to include(
          cbv_flow_id: 999_999_999,
          status: :skipped,
          reason: "CbvFlow record not found"
        )
      end
    end

    context "with filter_name: la_ldh_schema_error" do
      let(:schema_error) { "API Specification validation failed: response body did not match the schema" }
      let(:other_error) { "Connection refused - connect(2) for localhost" }
      let(:other_applicant) { create(:cbv_applicant, :la_ldh) }
      let(:other_flow) { create(:cbv_flow, cbv_applicant: other_applicant) }

      before do
        create_failed_execution(cbv_flow, error: schema_error)
        create_failed_execution(other_flow, error: other_error)
      end

      it "previews only schema validation failures" do
        result = service.preview(filter_name: "la_ldh_schema_error")

        expect(result[:count]).to eq(1)
        expect(result[:entries].first[:cbv_flow_id]).to eq(cbv_flow.id)
      end
    end

    context "with an unknown filter name" do
      it "raises a clear error" do
        expect { service.preview(filter_name: "unknown") }
          .to raise_error(ArgumentError, "Unknown caseworker mailer fallback filter: unknown")
      end
    end
  end
end
