require "rails_helper"

RSpec.describe Activities::ActivitiesController, type: :controller do
  describe "GET #index when session contains a different flow type" do
    it "resets the session and redirects when the session flow id can't be found" do
      # Simulate session containing an id that ActivityFlow cannot find (e.g. it's a CbvFlow id)
      session[:flow_id] = 999_999

      # Enable the activity hub so the before_action doesn't redirect early
      allow_any_instance_of(Activities::BaseController).to receive(:activity_hub_enabled?).and_return(true)

      allow(ActivityFlow).to receive(:find).with(999_999).and_raise(ActiveRecord::RecordNotFound)

      get :index

      expect(session[:flow_id]).to be_nil
      expect(response).to redirect_to(root_url(cbv_flow_timeout: true))
    end
  end
end
