require "rails_helper"

RSpec.describe CaseworkerMailerFallbackService do
  let(:service) { described_class.new }
  let(:la_ldh_applicant) { create(:cbv_applicant, :la_ldh) }
  let(:cbv_flow) { create(:cbv_flow, cbv_applicant: la_ldh_applicant) }
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

  describe "#call" do
    context "when there are no failed CaseWorkerTransmitterJob executions" do
      it "returns sent: 0 and empty skipped list" do
        result = service.call(schema_only: false)
        expect(result).to eq({ sent: 0, skipped: [] })
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
        result = service.call(schema_only: false)
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
        result = service.call(schema_only: false)
        expect(result[:sent]).to eq(0)
        expect(result[:skipped].first).to include("already transmitted")
      end
    end

    context "when the applicant has been redacted" do
      before do
        cbv_flow.cbv_applicant.redact!
        create_failed_execution(cbv_flow)
      end

      it "skips and reports the applicant as redacted" do
        result = service.call(schema_only: false)
        expect(result[:sent]).to eq(0)
        expect(result[:skipped].first).to include("applicant is redacted")
      end
    end

    context "when the agency has no caseworker_fallback_email" do
      let(:sandbox_flow) { create(:cbv_flow) }

      before { create_failed_execution(sandbox_flow) }

      it "skips and reports that no fallback email is configured" do
        result = service.call(schema_only: false)
        expect(result[:sent]).to eq(0)
        expect(result[:skipped].first).to include("no caseworker_fallback_email configured")
      end
    end

    context "when all conditions are met" do
      before { create_failed_execution(cbv_flow) }

      it "sends the email to the agency fallback address" do
        service.call(schema_only: false)
        expect(CaseworkerMailer).to have_received(:with).with(
          email_address: "MyMedicaid@la.gov",
          cbv_flow: cbv_flow,
          aggregator_report: mock_report
        )
        expect(mock_mail).to have_received(:deliver_now)
      end

      it "marks the flow as transmitted" do
        expect { service.call(schema_only: false) }
          .to change { cbv_flow.reload.transmitted_at }.from(nil)
      end

      it "destroys the failed execution" do
        expect { service.call(schema_only: false) }
          .to change(SolidQueue::FailedExecution, :count).by(-1)
      end

      it "returns sent: 1, skipped: []" do
        result = service.call(schema_only: false)
        expect(result).to eq({ sent: 1, skipped: [] })
      end
    end

    context "with schema_only: true" do
      let(:schema_error) { "API Specification validation failed: response body did not match the schema" }
      let(:other_error) { "Connection refused - connect(2) for localhost" }
      let(:other_applicant) { create(:cbv_applicant, :la_ldh) }
      let(:other_flow) { create(:cbv_flow, cbv_applicant: other_applicant) }

      before do
        create_failed_execution(cbv_flow, error: schema_error)
        create_failed_execution(other_flow, error: other_error)
      end

      it "sends only for schema validation failures, skipping other errors" do
        result = service.call(schema_only: true)
        expect(result[:sent]).to eq(1)
        expect(mock_mail).to have_received(:deliver_now).once
      end
    end
  end
end
