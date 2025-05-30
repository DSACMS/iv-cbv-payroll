require 'rails_helper'

RSpec.describe PayrollAccount::Argyle, type: :model do
  include ArgyleApiHelper

  let(:cbv_flow) { create(:cbv_flow) }
  let(:payroll_account) { create(:payroll_account, :argyle, cbv_flow: cbv_flow) }
  let(:synced_account) { create(:payroll_account, :argyle_fully_synced, cbv_flow: cbv_flow) }

  it "has a synchronization_status of 'unknown' by default" do
    payroll_account = cbv_flow.payroll_accounts.create
    expect(payroll_account.sync_unknown?).to eq(true)
  end

  describe '#has_fully_synced?' do
    it 'returns false when no webhook events exist' do
      expect(payroll_account.has_fully_synced?).to be false
    end

    it 'returns true when all supported jobs have corresponding webhook events' do
      expect(synced_account.has_fully_synced?).to be true
      expect(synced_account.webhook_events.count).to eq(Aggregators::Webhooks::Argyle.get_supported_jobs.count)
    end
  end

  describe '#job_succeeded?' do
    it 'returns true when the job succeeded' do
      expect(synced_account.job_succeeded?('identity')).to be true
    end
  end

  describe "#necessary_jobs_succeeded?" do
    let(:account) { create(:payroll_account, :argyle, cbv_flow: cbv_flow) }

    it "returns false when no webhooks have returned" do
      expect(payroll_account.necessary_jobs_succeeded?).to be false
    end

    it "returns false when only paystubs and gigs have been received" do
      create(:webhook_event, payroll_account: account, event_name: "paystubs.partially_synced", event_outcome: "success")
      create(:webhook_event, payroll_account: account, event_name: "gigs.partially_synced", event_outcome: "success")

      expect(payroll_account.necessary_jobs_succeeded?).to be false
    end

    context "when accounts has succeeded" do
      before do
        create(:webhook_event, payroll_account: account, event_name: "accounts.connected", event_outcome: "success")
      end

      it "returns true when paystubs succeeded" do
        create(:webhook_event, payroll_account: account, event_name: "paystubs.partially_synced", event_outcome: "success")

        expect(account.necessary_jobs_succeeded?).to be true
      end

      it "returns true when gigs succeeded" do
        create(:webhook_event, payroll_account: account, event_name: "gigs.partially_synced", event_outcome: "success")

        expect(account.necessary_jobs_succeeded?).to be true
      end

      it "returns true when paystubs.fully_synced has been received" do
        # this is the case for gig jobs where paystubs.partially_synced may
        # never be fetched
        create(:webhook_event, payroll_account: account, event_name: "paystubs.fully_synced", event_outcome: "success")

        expect(account.necessary_jobs_succeeded?).to be true
      end

      it "returns true when gigs.fully_synced has been received" do
        # this is the case for W2 jobs where gigs.partially_synced may
        # never be fetched
        create(:webhook_event, payroll_account: account, event_name: "gigs.fully_synced", event_outcome: "success")

        expect(account.necessary_jobs_succeeded?).to be true
      end

      it "returns false when an errored accounts.updated is received later" do
        create(:webhook_event, payroll_account: account, event_name: "accounts.updated", event_outcome: "error")

        expect(payroll_account.necessary_jobs_succeeded?).to be false
      end
    end
  end

  describe "#redact!" do
    let(:fake_argyle) { double(Aggregators::Sdk::ArgyleService, delete_account_api: nil) }

    before do
      expected_environment = Rails.application.config.client_agencies[cbv_flow.client_agency_id].argyle_environment

      allow(Aggregators::Sdk::ArgyleService)
        .to receive(:new)
        .with(expected_environment)
        .and_return(fake_argyle)
    end

    it "calls the DELETE /accounts/:id API" do
      payroll_account.redact!

      expect(fake_argyle).to have_received(:delete_account_api)
        .with(account: payroll_account.pinwheel_account_id)
    end

    it "updates the redacted_at timestamp" do
      expect { payroll_account.redact! }
        .to change { payroll_account.reload.redacted_at }
        .from(nil).to(within(1.second).of(Time.now))
    end

    context "when something goes wrong with the redaction process in production" do
      before do
        allow(fake_argyle).to receive(:delete_account_api)
          .with(account: payroll_account.pinwheel_account_id)
          .and_raise(StandardError.new("Random error occurred!"))

        allow(Rails.env).to receive(:production?).and_return(true)
        allow(Rails.logger).to receive(:error)

        allow_any_instance_of(NewRelicEventTracker)
          .to receive(:track)
      end

      it "logs to the Rails logger and to NewRelic" do
        expect_any_instance_of(NewRelicEventTracker)
          .to receive(:track)
          .with("DataRedactionFailure", nil, include(
            account_id: payroll_account.pinwheel_account_id
          ))
        expect(Rails.logger).to receive(:error).with(/Unable to redact/)

        payroll_account.redact!
      end
    end
  end
end
