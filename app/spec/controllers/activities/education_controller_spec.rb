require "rails_helper"
require "faker"

RSpec.describe Activities::EducationController, type: :controller do
  include_context "activity_hub"

  render_views

  let(:activity_flow) {
    create(
      :activity_flow,
      education_activities_count: 0,
      with_identity: true
    )
  }

  describe "GET #show" do
    let(:education_activity) { create(:education_activity, activity_flow: activity_flow, confirmed: true) }

    it "renders the education review page" do
      get :show, params: { education_activity_id: education_activity.id }, session: { flow_id: activity_flow.id, flow_type: :activity }

      expect(response).to have_http_status(:ok)
    end
  end

  describe "#create" do
    let(:initial_attrs) {
      attributes_for(
        :education_activity,
        activity_flow_id: activity_flow.id,
        confirmed: false,
      )
    }

    let (:new_attrs) {
      attributes_for(
        :education_activity,
        activity_flow_id: activity_flow.id,
        confirmed: false,
      )
    }

    let (:education_activity) {
      create(:education_activity, **initial_attrs)
    }

    let (:params) {
      {
          education_activity: {
            id: education_activity.id,
            credit_hours: new_attrs[:credit_hours],
            additional_comments: new_attrs[:additional_comments]
          }
        }
    }

    before do
      post(
        :create,
        params: params,
        session: {
          flow_id: activity_flow.id,
          flow_type: :activity
        }
      )

      education_activity.reload
    end

    it "updates mutable education activity attributes" do
      expect(education_activity).to have_attributes(
                                      **new_attrs.slice(
                                        :credit_hours, :additional_comments
                                      )
                                    )
    end

    it "does not update immutable education activity attributes" do
      expect(education_activity).to have_attributes(
                                      **initial_attrs.slice(
                                        :school_name, :school_address, :status
                                      )
                                    )
    end

    it "confirms the education activity" do
      expect(education_activity.confirmed).to be_truthy
    end

    it "redirects to activity hub" do
      expect(response).to redirect_to(activities_flow_root_path)
      expect(flash[:notice]).to eq(I18n.t("activities.education.created"))
    end
  end

  describe "DELETE #destroy" do
    let!(:education_activity) { create(:education_activity, activity_flow: activity_flow, confirmed: true) }

    it "deletes the activity and redirects to the hub" do
      expect do
        delete :destroy, params: { education_activity_id: education_activity.id }, session: { flow_id: activity_flow.id, flow_type: :activity }
      end.to change(activity_flow.education_activities, :count).by(-1)

      expect(response).to redirect_to(activities_flow_root_path)
      expect(flash[:notice]).to eq(I18n.t("activities.education.deleted"))
    end
  end
end
