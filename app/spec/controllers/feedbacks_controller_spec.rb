require "rails_helper"

RSpec.describe FeedbacksController, type: :controller do
  describe "GET #show" do
    let(:event_logger) { instance_double(GenericEventTracker) }
    let(:feedback_form_url) { ApplicationHelper::APPLICANT_FEEDBACK_FORM }
    let(:cbv_flow) { create(:cbv_flow, :invited) }

    before do
      session[:flow_id] = cbv_flow.id
      allow(controller).to receive(:event_logger).and_return(event_logger)
      allow(event_logger).to receive(:track)
      allow(ApplicationController.helpers).to receive(:feedback_form_url).and_return(feedback_form_url)
    end

    context "with device_id cookie" do
      before do
        cookies.permanent.signed[:device_id] = "test-device-id-123"
      end

      it "redirects to the feedback form with prefill params and tracks the event" do
        referer_url = cbv_flow_employer_search_path(locale: :en)
        get :show, params: { referer: referer_url }

        expect(event_logger).to have_received(:track).with(
          "ApplicantClickedFeedbackLink",
          kind_of(ActionDispatch::Request),
          hash_including(
            referer: referer_url,
            client_agency_id: cbv_flow.cbv_applicant.client_agency_id,
            cbv_flow_id: cbv_flow.id
          )
        )
        expect(response).to have_http_status(:redirect)
        agency_prefixed_device_id = CGI.escape("#{cbv_flow.cbv_applicant.client_agency_id}/test-device-id-123")
        expected_url = "#{feedback_form_url}?usp=pp_url&#{ApplicationHelper::FEEDBACK_FORM_DEVICE_ID_ENTRY}=#{agency_prefixed_device_id}"
        expect(response.location).to eq(expected_url)
      end

      it "redirects to the survey form without prefill params" do
        get :show, params: { form: "survey" }

        expect(event_logger).to have_received(:track).with(
          "ApplicantClickedFeedbackSurveyLink",
          kind_of(ActionDispatch::Request),
          hash_including(
            client_agency_id: cbv_flow.cbv_applicant.client_agency_id,
            cbv_flow_id: cbv_flow.id
          )
        )
        expect(response).to have_http_status(:redirect)
        expect(response.location).to eq(ApplicationController.helpers.survey_form_url)
      end
    end

    context "without device_id cookie" do
      before do
        allow(controller).to receive(:set_device_id_cookie)
      end

      it "redirects to the base feedback form URL" do
        get :show, params: { referer: "http://example.com" }

        expect(response).to have_http_status(:redirect)
        expect(response.location).to eq(feedback_form_url)
      end
    end
  end
end
