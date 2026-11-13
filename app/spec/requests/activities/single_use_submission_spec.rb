require "rails_helper"
require "timeout"

RSpec.describe "Concurrent single-use activity submissions", type: :request do
  include_context "activity_hub"

  # Separate connections must see committed fixtures and contend on real locks.
  self.use_transactional_tests = false

  let(:applicant) { create(:cbv_applicant, client_agency_id: "sandbox") }
  let(:invitation) { create(:activity_flow_invitation, cbv_applicant: applicant, employment_focused: true) }
  let(:ready) { Queue.new }
  let(:release) { Queue.new }
  let(:workers) { [] }
  let(:sessions) { Array.new(2) { ActionDispatch::Integration::Session.new(Rails.application) } }

  before do
    allow(Rails.application.config.client_agencies["sandbox"])
      .to receive(:allow_activity_invitation_reuse).and_return(false)
    allow(ActivityFlowTransmitterJob).to receive(:perform_later)

    sessions.each do |browser|
      browser.get activities_flow_start_path(token: invitation.auth_token)
      flow = invitation.activity_flows.order(:id).last
      create(:employment_activity, activity_flow: flow)
    end

    # Hold both requests immediately before the lock, ensuring neither sees
    # a completed flow in its initial controller checks.
    allow_any_instance_of(ActivityFlowInvitation).to receive(:lock!).and_wrap_original do |original, *args|
      ready << true
      release.pop
      original.call(*args)
    end
  end

  after do
    workers.each { |worker| worker.kill if worker.alive? }
    workers.each(&:join)
    invitation.activity_flows.each(&:destroy!)
    invitation.destroy!
    applicant.destroy!
  end

  it "finalizes and queues only one report and expires the losing session" do
    sessions.each do |browser|
      workers << Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          browser.patch activities_flow_summary_path, params: { activity_flow: { consent_to_submit: "1" } }
        end
      end
    end

    Timeout.timeout(15) do
      2.times { ready.pop }
      2.times { release << true }
      workers.each(&:value)
    end

    expect(invitation.activity_flows.completed.count).to eq(1)
    expect(invitation.activity_flows.incomplete.sole.confirmation_code).to be_nil
    expect(ActivityFlowTransmitterJob).to have_received(:perform_later).once
    expect(sessions.map { |browser| URI(browser.response.location).path }).to contain_exactly(
      activities_flow_success_path, activities_flow_expired_invitation_path
    )
  end
end
