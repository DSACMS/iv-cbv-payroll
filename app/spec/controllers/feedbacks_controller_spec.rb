require "rails_helper"

RSpec.describe FeedbacksController, type: :controller do
  describe "GET #show" do
    let(:event_logger) { instance_double(GenericEventTracker) }
    let(:feedback_form_url) { ApplicationHelper::APPLICANT_FEEDBACK_FORM }
    let(:cbv_flow) { create(:cbv_flow, :invited) }

    before do
      session[:cbv_flow_id] = cbv_flow.id
      allow(controller).to receive(:event_logger).and_return(event_logger)
      allow(event_logger).to receive(:track)
      allow(ApplicationController.helpers).to receive(:feedback_form_url).and_return(feedback_form_url)
    end

    it "redirects to the feedback form and tracks the event with source" do
      # see https://github.com/rspec/rspec-rails/issues/1655#issuecomment-250418438
      request.headers.merge!('HTTP_REFERER' => cbv_flow_entry_path(locale: :en))

      get :show

      expect(event_logger).to have_received(:track).with(
        "ApplicantClickedFeedbackLink",
        kind_of(ActionDispatch::Request),
        hash_including(
          referer: cbv_flow_entry_path(locale: :en),
          client_agency_id: cbv_flow.client_agency_id,
          cbv_flow_id: cbv_flow.id
        )
      )
      expect(response).to have_http_status(:redirect)
      expect(response.location).to eq(ApplicationController.helpers.feedback_form_url)
    end
  end
end
