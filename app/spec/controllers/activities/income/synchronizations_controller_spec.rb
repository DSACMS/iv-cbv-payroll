require "rails_helper"

RSpec.describe Activities::Income::SynchronizationsController do
  include_context "activity_hub"
  render_views

  let(:flow) { create(:activity_flow) }
  let(:errored_jobs) { [] }
  let(:payroll_account) { create(:payroll_account, :pinwheel_fully_synced, with_errored_jobs: errored_jobs, flow: flow) }

  before do
    session[:flow_id] = flow.id
    session[:flow_type] = :activity
  end

  describe "#show" do
    let(:applicant) { create(:cbv_applicant, first_name: "Lisa", last_name: "Williams") }
    let(:invitation) { create(:activity_flow_invitation, cbv_applicant: applicant) }
    let(:flow) { create(:activity_flow, cbv_applicant: applicant, activity_flow_invitation: invitation) }
    let(:reporting_for_text) {
      I18n.t("activities.reporting_for.text_html", name: "#{applicant.first_name} #{applicant.last_name}")
    }

    before do
      allow_any_instance_of(PayrollAccount::Pinwheel).to receive(:has_fully_synced?).and_return(false)
      get :show, params: { user: { account_id: payroll_account.aggregator_account_id } }
    end

    it "does not display the reporting banner for a named applicant in a tokenized flow" do
      expect(response).to have_http_status(:ok)
      expect(Capybara.string(response.body)).to have_no_text(reporting_for_text)
    end
  end

  describe "#update" do
    context "when account exists but is not fully synced" do
      before do
        allow_any_instance_of(PayrollAccount::Pinwheel).to receive(:has_fully_synced?).and_return(false)
      end

      it "renders the page" do
        patch :update, params: { user: { account_id: payroll_account.aggregator_account_id } }

        expect(response.body).to include("id=\"synchronization\"")
      end

      it "does not render the activity flow header" do
        patch :update, params: { user: { account_id: payroll_account.aggregator_account_id } }

        expect(response.body).not_to include("exit-confirmation-modal")
      end
    end
  end

  describe "sync delay alerts" do
    let(:payroll_account) { create(:payroll_account, flow: flow, created_at: started_at) }
    let(:started_at) { Time.current }
    let(:params) { { user: { account_id: payroll_account.aggregator_account_id }, locale: locale } }
    let(:locale) { :en }
    let(:heading) { I18n.t("application.sync_delay_alert.heading", locale: locale) }
    let(:body) { I18n.t("application.sync_delay_alert.body", locale: locale) }
    let(:alerts) { "" }

    around do |example|
      Timecop.freeze(Time.current.change(usec: 0)) do
        stub_environment_variable("ENABLED_ALERTS", alerts, &example)
      end
    end

    it "shows normal progress for a new synchronization" do
      get :show, params: params

      expect(Capybara.string(response.body)).to have_no_text(heading)
    end

    context "at exactly five minutes" do
      let(:started_at) { 5.minutes.ago }

      it "continues showing normal progress on initial load and polling" do
        get :show, params: params
        expect(Capybara.string(response.body)).to have_no_text(heading)

        patch :update, params: params
        expect(response.body).not_to include(heading)
      end
    end

    context "after five minutes" do
      let(:started_at) { 5.minutes.ago - 1.second }

      it "renders a full-page message and document title on initial load" do
        get :show, params: params

        expect(Capybara.string(response.body)).to have_selector("h1", text: heading, count: 1)
        expect(Capybara.string(response.body)).to have_text(body)
        expect(Capybara.string(response.body)).to have_selector("title", text: heading, visible: :all)
      end

      it "replaces progress and supplies the new document title on the next poll" do
        patch :update, params: params

        expect(response.body).to include('turbo-stream action="replace" target="synchronization"')
        expect(response.body).to include(heading, ERB::Util.html_escape(body), 'data-polling-target="status"')
        expect(response.body).not_to include('action="redirect"')
      end

      context "in Spanish" do
        let(:locale) { :es }

        it "uses the approved Spanish heading and body on initial load and polling" do
          get :show, params: params
          expect(Capybara.string(response.body)).to have_selector("h1", text: "La sincronización está tardando más de lo normal")
          expect(Capybara.string(response.body)).to have_text(body)

          patch :update, params: params
          expect(response.body).to include(heading, body)
        end
      end
    end

    it "changes from normal progress to a delay message during polling" do
      get :show, params: params
      expect(Capybara.string(response.body)).to have_no_text(heading)

      Timecop.travel(5.minutes.from_now + 1.second) do
        patch :update, params: params
        expect(response.body).to include(heading)
      end
    end

    context "with no payroll account yet" do
      let(:params) { { user: { account_id: "not-created-yet" } } }

      it "keeps polling without assuming a delay" do
        get :show, params: params
        expect(Capybara.string(response.body)).to have_no_text(heading)

        patch :update, params: params
        expect(response.body).to include('target="synchronization"')
        expect(response.body).not_to include(heading)
      end
    end

    context "when manually enabled" do
      let(:alerts) { "site_alert, sync_delays" }

      it "shows the message immediately on initial load and polling" do
        get :show, params: params
        expect(Capybara.string(response.body)).to have_selector("h1", text: heading)

        patch :update, params: params
        expect(response.body).to include(heading)
      end

      context "with no payroll account yet" do
        let(:params) { { user: { account_id: "not-created-yet" } } }

        it "shows the manual message while waiting for the account" do
          get :show, params: params
          expect(Capybara.string(response.body)).to have_selector("h1", text: heading)
        end
      end

      context "when synchronization completes" do
        let(:payroll_account) { create(:payroll_account, :pinwheel_fully_synced, flow: flow, created_at: 10.minutes.ago) }

        it "still redirects to payment details on initial load and polling" do
          get :show, params: params
          expect(response).to have_http_status(:redirect)
          expect(response.location).to include("payment_details")

          patch :update, params: params
          expect(response.body).to include('action="redirect"', "payment_details")
        end
      end

      context "when synchronization fails" do
        let(:payroll_account) { create(:payroll_account, :argyle_system_error_encountered, flow: flow, created_at: 10.minutes.ago) }

        it "still redirects to synchronization failures during polling" do
          patch :update, params: params

          expect(response.body).to include('action="redirect"', "synchronization_failures")
        end
      end
    end
  end
end
