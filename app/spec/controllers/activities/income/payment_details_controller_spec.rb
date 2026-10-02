require "rails_helper"

RSpec.describe Activities::Income::PaymentDetailsController do
  include PinwheelApiHelper
  include ArgyleApiHelper

  include_context "activity_hub"

  describe "#show" do
    render_views

    let(:account_id) { "03e29160-f7e7-4a28-b2d8-813640e030d3" }
    let(:flow) { create(:activity_flow) }

    before do
      session[:flow_id] = flow.id
      session[:flow_type] = :activity
    end

    context "for a Pinwheel account" do
      let!(:payroll_account) do
        create(
          :payroll_account,
          :pinwheel_fully_synced,
          flow: flow,
          aggregator_account_id: account_id,
        )
      end

      before do
        pinwheel_stub_request_identity_response
        pinwheel_stub_request_end_user_accounts_response
        pinwheel_stub_request_end_user_account_response
        pinwheel_stub_request_platform_response
        pinwheel_stub_request_income_metadata_response
        pinwheel_stub_request_employment_info_response
        pinwheel_stub_request_end_user_paystubs_response
      end

      it_behaves_like "an activity header controlled by employment focus", :flow, -> { get :show, params: { user: { account_id: account_id } } }


      it "renders properly" do
        get :show, params: { user: { account_id: account_id } }

        expect(response).to be_successful
        page = Capybara.string(response.body)
        expect(page).to have_css("h2", text: I18n.t("shared.table_headers.employer_information"))
        expect(response.body).to include(I18n.t("components.report.monthly_summary_table.activity.community_engagement_hours"))
        expect(response.body).to include(I18n.t("components.report.monthly_summary_table.activity.payment_information"))
      end

      it "renders the employment-focused tables before additional comments" do
        flow.update!(employment_focused: true, reporting_window_months: 3)

        get :show, params: { user: { account_id: account_id } }

        page = Capybara.string(response.body)
        headings = page.all("h2").map(&:text)
        expect(headings.first(3)).to eq([ "Employment information", "Monthly details", "Additional comments (optional)" ])
        expect(page).to have_selector("table", count: 4)
        expect(page).to have_text("Compensation amount")
        expect(page).to have_field("payroll_account_additional_information")
        expect(page).to have_no_text("Community engagement hours")
      end

      [ 1, 3 ].each do |months|
        [ false, true ].each do |employment_focused|
          it "uses the correct report description for #{months} months with employment focus #{employment_focused}" do
            flow.update!(reporting_window_months: months, employment_focused: employment_focused)

            get :show, params: { user: { account_id: account_id } }

            page = Capybara.string(response.body)
            expect(page).to have_text("Please review your information.")
            sentence = "This will be included in your community engagement report."
            if employment_focused
              expect(page).to have_no_text(sentence)
            else
              expect(page).to have_text(sentence)
            end
          end
        end
      end

      it "renders the activity flow header with exit button and back link" do
        get :show, params: { user: { account_id: account_id } }

        expect(response.body).to include(I18n.t("activities.employment.title_singular"))
        expect(response.body).to include("exit-confirmation-modal")
        expect(response.body).to include("back-nav")
      end

      it "describes a multi-month reporting window with month labels" do
        get :show, params: { user: { account_id: account_id } }

        start_month = I18n.l(flow.reporting_window_range.begin, format: :month_year)
        end_month = I18n.l(flow.reporting_window_range.end, format: :month_year)

        expect(response.body).to include("We have gathered your records from #{start_month} to #{end_month}.")
      end

      it "describes a single-month reporting window with one month label" do
        flow.update!(reporting_window_months: 1)

        get :show, params: { user: { account_id: account_id } }

        month = I18n.l(flow.reporting_window_range.begin, format: :month_year)
        expect(response.body).to include("We have gathered your records for #{month}.")
      end

      it "tracks viewed payment details with activity_flow_id" do
        allow(EventTrackingJob).to receive(:perform_later).with(TrackEvent::CbvPageView, anything, anything)
        expect(EventTrackingJob).to receive(:perform_later).with(TrackEvent::ApplicantViewedPaymentDetails, anything, hash_including(
          activity_flow_id: flow.id,
          invitation_id: flow.activity_flow_invitation_id,
          aggregator_account_id: payroll_account.id,
          payments_length: 1,
          has_employment_data: true,
          has_paystubs_data: true,
          has_income_data: true
        ))

        get :show, params: { user: { account_id: account_id } }
      end
    end

    context "for Argyle Bob (a Gig worker)" do
      let(:account_id) { ArgyleApiHelper::BOB_ACCOUNT_ID }

      before do
        create(
          :payroll_account,
          :argyle_fully_synced,
          flow: flow,
          aggregator_account_id: account_id
        )

        argyle_stub_request_identities_response("bob")
        argyle_stub_request_paystubs_response("bob")
        argyle_stub_request_gigs_response("bob")
        argyle_stub_request_account_response("bob")
        get :show, params: { user: { account_id: account_id } }
      end

      it "renders successfully" do
        expect(response).to be_successful
        expect(response.body).to include(I18n.t("components.report.monthly_summary_table.activity.gross_income"))
        expect(response.body).to include(I18n.t("components.report.monthly_summary_table.activity.mileage_expenses"))
        expect(response.body).to include(I18n.t("components.report.monthly_summary_table.activity.community_engagement_hours"))
      end
    end

    context "for an Argyle W2 user like Kim but who has no data" do
      let(:account_id) { ArgyleApiHelper::KIM_ACCOUNT_ID }

      before do
        create(
          :payroll_account,
          :argyle_fully_synced,
          flow: flow,
          aggregator_account_id: account_id
        )

        argyle_stub_request_identities_response("kim")
        argyle_stub_request_paystubs_response("empty")
        argyle_stub_request_gigs_response("empty")
        argyle_stub_request_account_response("kim")
        get :show, params: { user: { account_id: account_id } }
      end

      it "renders successfully" do
        expect(response).to be_successful
        expect(response.body).to have_text(I18n.t("activities.income.payment_details.show.none_found"))
      end

      it "describes the missing income range with month labels" do
        start_month = I18n.l(flow.reporting_window_range.begin, format: :month_year)
        end_month = I18n.l(flow.reporting_window_range.end, format: :month_year)

        expect(response.body).to include("between #{start_month} and #{end_month}")
      end
    end
  end

  describe "#update" do
    let(:account_id) { "03e29160-f7e7-4a28-b2d8-813640e030d3" }
    let(:comment) { "This is a test comment" }
    let(:old_comment) { "Old comment" }
    let(:flow) { create(:activity_flow) }
    let!(:payroll_account) do
      create(
        :payroll_account,
        :pinwheel_fully_synced,
        flow: flow,
        aggregator_account_id: account_id,
        additional_information: old_comment,
      )
    end

    before do
      session[:flow_id] = flow.id
      session[:flow_type] = :activity
    end

    it "updates the account comment" do
      expect do
        patch :update, params: {
          user: { account_id: account_id },
          payroll_account: { additional_information: comment }
        }
      end.to change { payroll_account.reload.additional_information }
        .from(old_comment)
        .to(comment)
    end

    it "publishes the payroll account" do
      payroll_account.update!(draft: true)

      patch :update, params: {
        user: { account_id: account_id },
        payroll_account: { additional_information: comment }
      }

      expect(payroll_account.reload.draft).to be(false)
    end

    it "tracks saved payment details with activity_flow_id" do
      allow(EventTrackingJob).to receive(:perform_later).with("CbvPageView", anything, anything)
      expect(EventTrackingJob).to receive(:perform_later).with("ApplicantSavedPaymentDetails", anything, hash_including(
        activity_flow_id: flow.id,
        invitation_id: flow.activity_flow_invitation_id,
        additional_information_length: comment.length
      ))

      patch :update, params: {
        user: { account_id: account_id },
        payroll_account: { additional_information: comment }
      }
    end
  end
end
