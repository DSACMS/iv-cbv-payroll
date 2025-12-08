require "rails_helper"
require "faker"

RSpec.describe Activities::EducationController, type: :controller do
  render_views

  let(:activity_flow) {
    create(
      :activity_flow,
      education_activities_count: 0,
      with_identity: true
    )
  }

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
          activity_flow_id: activity_flow.id
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
end
