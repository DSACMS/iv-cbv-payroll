require "rails_helper"

RSpec.describe "CMS NSC alert smoke test" do # rubocop:disable RSpec/DescribeClass -- Exercises a standalone console script.
  let(:script_path) { Rails.root.join("../docs/infra/nsc_alert_smoke_test.rb") }

  before do
    allow(NewRelic::Agent).to receive(:config).and_return(app_name: [ "Iv Cbv Payroll (Dev)" ])
    allow(NewRelic::Agent).to receive(:manual_start)
    allow(NewRelic::Agent).to receive(:shutdown)
    allow(NewRelic::Agent).to receive(:increment_metric)
    allow(NewRelic::Agent).to receive(:record_metric)
    allow(NewRelic::Agent).to receive(:record_custom_event)
    allow(NewRelic::Agent).to receive(:notice_error)
  end

  it "exercises both application signals without making an HTTP request" do
    ClimateControl.modify(DOMAIN_NAME: "pr-2075.dev.emmy.cms.gov") do
      expect { load script_path }.to output(/Check New Relic for BOTH incidents/).to_stdout
    end

    expect(NewRelic::Agent).to have_received(:increment_metric).with("Custom/NSC/Failure").once
    expect(NewRelic::Agent).to have_received(:notice_error).with(
      instance_of(Aggregators::Sdk::NscFdshService::ApiError)
    ).once
    expect(NewRelic::Agent).to have_received(:notice_error).with(
      instance_of(Aggregators::Sdk::NscCertificateService::CertificateExpiringSoonError),
      hash_including(custom_params: hash_including(status: :expiring_soon))
    ).once
    expect(WebMock).not_to have_requested(:any, /synthetic.invalid/)
    expect(NewRelic::Agent).to have_received(:shutdown).once
  end

  it "refuses another environment before emitting telemetry" do
    ClimateControl.modify(DOMAIN_NAME: "prod.emmy.cms.gov") do
      expect { load script_path }.to raise_error("Run inside PR 2075's review task")
    end

    expect(NewRelic::Agent).not_to have_received(:manual_start)
    expect(NewRelic::Agent).not_to have_received(:increment_metric)
    expect(NewRelic::Agent).not_to have_received(:notice_error)
  end
end
