require "rails_helper"

RSpec.describe Cbv::PaymentDetailsController do
  include PinwheelApiHelper

  describe "#show" do
    render_views

    let(:current_time) { Date.parse('2024-06-18') }
    let(:cbv_applicant) { create(:cbv_applicant, created_at: current_time, case_number: "ABC1234") }
    let(:account_id) { SecureRandom.uuid }
    let(:comment) { "This is a test comment" }
    let(:supported_jobs) { %w[income paystubs employment] }
    let(:errored_jobs) { [] }
    let(:cbv_flow) do
      create(:cbv_flow,
        :with_pinwheel_account,
        with_errored_jobs: errored_jobs,
        created_at: current_time,
        supported_jobs: supported_jobs,
        cbv_applicant: cbv_applicant
      )
    end
    let!(:payroll_account) do
      create(
        :payroll_account,
        :pinwheel_fully_synced,
        with_errored_jobs: errored_jobs,
        cbv_flow: cbv_flow,
        pinwheel_account_id: account_id,
        supported_jobs: supported_jobs,
      )
    end

    before do
      session[:cbv_flow_id] = cbv_flow.id
      pinwheel_stub_request_end_user_accounts_response
      pinwheel_stub_request_end_user_paystubs_response
      pinwheel_stub_request_income_metadata_response if supported_jobs.include?("income")
      pinwheel_stub_request_employment_info_response
    end

    context "when pinwheel values are present" do
      it "renders properly" do
        get :show, params: { user: { account_id: account_id } }
        expect(response).to be_successful
      end

      it "tracks events" do
        expect_any_instance_of(MixpanelEventTracker)
          .to receive(:track)
          .with("ApplicantViewedPaymentDetails", anything, hash_including(
            cbv_flow_id: cbv_flow.id,
            invitation_id: cbv_flow.cbv_flow_invitation_id,
            pinwheel_account_id: payroll_account.id,
            payments_length: 1,
            has_employment_data: true,
            has_paystubs_data: true,
            has_income_data: true
          ))

        expect_any_instance_of(NewRelicEventTracker)
          .to receive(:track)
          .with("ApplicantViewedPaymentDetails", anything, hash_including(
            cbv_flow_id: cbv_flow.id,
            invitation_id: cbv_flow.cbv_flow_invitation_id,
            pinwheel_account_id: payroll_account.id,
            payments_length: 1,
            has_employment_data: true,
            has_paystubs_data: true,
            has_income_data: true
          ))

        get :show, params: { user: { account_id: account_id } }
      end

      context "when account comment exists" do
        let(:updated_at) { Time.current.iso8601 }

        before do
          additional_information = { account_id => { comment: comment, updated_at: updated_at } }
          cbv_flow.update!(additional_information: additional_information)

          # Verify that the comment was saved
          loaded_info = cbv_flow.reload.additional_information
          expect(loaded_info[account_id]["comment"]).to eq(comment)
          expect(loaded_info[account_id]["updated_at"]).to eq(updated_at)
        end

        it "includes the account comment in the response" do
          get :show, params: { user: { account_id: account_id } }
          expect(response.body).to include(comment)
        end
      end

      context "when multiple comments exist for different accounts" do
        let(:account_id_2) { SecureRandom.uuid }
        let(:comment_2) { "This is another test comment" }
        let(:updated_at) { Time.current.iso8601 }

        before do
          additional_information = {
            account_id => { comment: comment, updated_at: updated_at },
            account_id_2 => { comment: comment_2, updated_at: updated_at }
          }

          cbv_flow.update!(additional_information: additional_information)

          # Verify that the comments were saved
          loaded_info = cbv_flow.reload.additional_information
          expect(loaded_info[account_id]["comment"]).to eq(comment)
          expect(loaded_info[account_id]["updated_at"]).to eq(updated_at)
          expect(loaded_info[account_id_2]["comment"]).to eq(comment_2)
          expect(loaded_info[account_id_2]["updated_at"]).to eq(updated_at)

          # Verify that there are two comments
          expect(loaded_info.keys).to contain_exactly(account_id, account_id_2)
        end

        it "includes the account comments in the response" do
          get :show, params: { user: { account_id: account_id } }
          expect(response.body).to include(comment)
          expect(response.body).not_to include(comment_2)
        end
      end

      context "when account comment does not exist" do
        it "does not include an account comment in the response" do
          get :show, params: { user: { account_id: account_id } }
          expect(response.body).not_to include(comment)
        end
      end
    end

    context "for an account that doesn't support income data" do
      let(:supported_jobs) { %w[paystubs employment] }

      it "renders properly without the income data" do
        get :show, params: { user: { account_id: account_id } }
        expect(response).to be_successful
        expect(response.body).not_to include("Pay period frequency")
      end
    end

    context "for an account that supports income data but Pinwheel was unable to retrieve it" do
      let(:supported_jobs) { %w[paystubs employment income] }
      let(:errored_jobs) { [ "income" ] }

      it "renders properly without the income data" do
        get :show, params: { user: { account_id: account_id } }
        expect(response).to be_successful
        expect(response.body).not_to include("Pay period frequency")
      end
    end


    context "for an account that supports employment data but Pinwheel was unable to retrieve" do
      let(:supported_jobs) { %w[paystubs employment income] }
      let(:errored_jobs) { [ "employment" ] }

      it "renders properly without the employment data" do
        get :show, params: { user: { account_id: account_id } }
        expect(response).to be_successful
        expect(response.body).to include("Unknown")
      end
    end

    context "for an account that supports paystubs data but Pinwheel was unable to retrieve" do
      let(:supported_jobs) { %w[paystubs employment income] }
      let(:errored_jobs) { [ "paystubs" ] }

      it "renders properly without the paystubs data" do
        get :show, params: { user: { account_id: account_id } }
        expect(response).to be_successful
        expect(response.body).to include("find any payments from this employer in the past 90 days.")
      end
    end

    context "when employment status is blank" do
      before do
        pinwheel_request_employment_info_response_null_employment_status_bug
      end

      it "renders properly" do
        get :show, params: { user: { account_id: account_id } }
        expect(response).to be_successful
      end
    end

    context "when deductions include a zero dollar amount" do
      it "does not show that deduction" do
        get :show, params: { user: { account_id: account_id } }
        expect(response.body).to include("Commuter")
        expect(response.body).not_to include("Empty deduction")
      end
    end

    context "when a user attempts to access pinwheel account information not in the current session" do
      it "redirects to the entry page when the resolved pinwheel_account is nil" do
        get :show, params: { user: { account_id: "1234" } }
        expect(response).to redirect_to(cbv_flow_entry_url)
        expect(flash[:slim_alert]).to be_present
        expect(flash[:slim_alert][:message]).to eq(I18n.t("cbv.error_no_access"))
      end

      it "redirects to the entry page when the resolved pinwheel_account is present, but does not match the current session" do
        existing_payroll_account = create(:payroll_account)
        get :show, params: { user: { account_id: existing_payroll_account.pinwheel_account_id } }
        expect(response).to redirect_to(cbv_flow_entry_url)
        expect(flash[:slim_alert]).to be_present
        expect(flash[:slim_alert][:message]).to eq(I18n.t("cbv.error_no_access"))
      end
    end
  end

  describe "#update" do
    let!(:cbv_flow) { create(:cbv_flow) }
    let(:account_id) { SecureRandom.uuid }
    let(:comment) { "This is a test comment" }

    before do
      session[:cbv_flow_id] = cbv_flow.id
      # update the cbv_flow to have an account comment
      additional_information = { account_id => { comment: "Old comment", updated_at: Time.current.iso8601 } }
      cbv_flow.update!(additional_information: additional_information)
    end

    it "updates the account comment through invoking the controller" do
      additional_information = cbv_flow.additional_information
      # a bit redundant, but prior to invoking the controller action- the comment should be different
      expect(additional_information[account_id]["comment"]).not_to eq(comment)
      # invoke the controller action
      patch :update, params: { user: { account_id: account_id }, cbv_flow: { additional_information: comment } }
      # verify that the comment was updated. the reload method does not deserialize the JSON field
      additional_information = cbv_flow.reload.additional_information
      expect(additional_information[account_id]["comment"]).to eq(comment)
    end

    it "tracks events" do
      expect_any_instance_of(MixpanelEventTracker)
        .to receive(:track)
        .with("ApplicantSavedPaymentDetails", anything, hash_including(
          cbv_flow_id: cbv_flow.id,
          invitation_id: cbv_flow.cbv_flow_invitation_id,
          additional_information_length: comment.length
        ))

      expect_any_instance_of(NewRelicEventTracker)
        .to receive(:track)
        .with("ApplicantSavedPaymentDetails", anything, hash_including(
          cbv_flow_id: cbv_flow.id,
          invitation_id: cbv_flow.cbv_flow_invitation_id,
          additional_information_length: comment.length
        ))

      patch :update, params: { user: { account_id: account_id }, cbv_flow: { additional_information: comment } }
    end
  end
end
