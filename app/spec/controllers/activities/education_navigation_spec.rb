require "rails_helper"
# rubocop:disable RSpec/MultipleDescribes

RSpec.describe Activities::EducationController, type: :controller do
  include_context "activity_hub"

  render_views

  let(:activity_flow) do
    create(:activity_flow,
      volunteering_activities_count: 0,
      job_training_activities_count: 0,
      education_activities_count: 0,
      reporting_window_months: 2)
  end
  let(:education_activity) do
    create(:education_activity,
      activity_flow: activity_flow,
      data_source: :fully_self_attested,
      school_name: "Test University")
  end

  before do
    session[:flow_id] = activity_flow.id
    session[:flow_type] = :activity
  end

  # ── Creation flow ──

  describe "creation flow" do
    it "school info has no back button" do
      get :new
      expect(Capybara.string(response.body)).not_to have_css(".back-nav")
    end

    it "review back goes to document uploads" do
      get :review, params: { id: education_activity.id }
      expected = new_activities_flow_education_document_upload_path(
        education_id: education_activity)
      expect(Capybara.string(response.body)).to have_css(".back-nav__link[href='#{expected}']")
    end
  end

  # ── Edit from review ──

  describe "edit from review" do
    it "school info back goes to review" do
      get :edit, params: { id: education_activity.id, from_review: 1 }
      expected = review_activities_flow_education_path(id: education_activity)
      expect(Capybara.string(response.body)).to have_css(".back-nav__link[href='#{expected}']")
    end

    it "school info back goes to review with from_edit when editing from hub" do
      get :edit, params: { id: education_activity.id, from_review: 1, from_edit: 1 }
      expected = review_activities_flow_education_path(id: education_activity, from_edit: 1)
      expect(Capybara.string(response.body)).to have_css(".back-nav__link[href='#{expected}']")
    end
  end

  # ── Edit from hub ──

  describe "edit from hub" do
    it "school info edit has no back button" do
      get :edit, params: { id: education_activity.id }
      expect(Capybara.string(response.body)).not_to have_css(".back-nav")
    end

    it "review has no back button" do
      get :review, params: { id: education_activity.id, from_edit: 1 }
      expect(Capybara.string(response.body)).not_to have_css(".back-nav")
    end
  end
end

RSpec.describe Activities::Education::MonthsController, type: :controller do
  include_context "activity_hub"

  render_views

  let(:activity_flow) do
    create(:activity_flow,
      volunteering_activities_count: 0,
      job_training_activities_count: 0,
      education_activities_count: 0,
      reporting_window_months: 2)
  end
  let(:education_activity) do
    create(:education_activity,
      activity_flow: activity_flow,
      data_source: :fully_self_attested,
      school_name: "Test University")
  end

  before do
    session[:flow_id] = activity_flow.id
    session[:flow_type] = :activity
  end

  # ── Creation flow ──

  describe "creation flow" do
    it "month 0 back goes to school info edit" do
      get :edit, params: { education_id: education_activity.id, id: 0 }
      expected = edit_activities_flow_education_path(id: education_activity)
      expect(Capybara.string(response.body)).to have_css(".back-nav__link[href='#{expected}']")
    end

    it "month 1 back goes to month 0" do
      get :edit, params: { education_id: education_activity.id, id: 1 }
      expected = edit_activities_flow_education_month_path(
        education_id: education_activity, id: 0)
      expect(Capybara.string(response.body)).to have_css(".back-nav__link[href='#{expected}']")
    end

    it "month 1 with from_edit back goes to month 0 with from_edit" do
      get :edit, params: { education_id: education_activity.id, id: 1, from_edit: 1 }
      expected = edit_activities_flow_education_month_path(
        education_id: education_activity, id: 0, from_edit: 1)
      expect(Capybara.string(response.body)).to have_css(".back-nav__link[href='#{expected}']")
    end
  end

  # ── Edit from review ──

  describe "edit from review" do
    it "month 0 back goes to review" do
      get :edit, params: { education_id: education_activity.id, id: 0, from_review: 1 }
      expected = review_activities_flow_education_path(id: education_activity)
      expect(Capybara.string(response.body)).to have_css(".back-nav__link[href='#{expected}']")
    end

    it "month 1 back goes to review" do
      get :edit, params: { education_id: education_activity.id, id: 1, from_review: 1 }
      expected = review_activities_flow_education_path(id: education_activity)
      expect(Capybara.string(response.body)).to have_css(".back-nav__link[href='#{expected}']")
    end
  end

  # ── Edit from hub ──

  describe "edit from hub" do
    it "month 0 back goes to review with from_edit" do
      get :edit, params: { education_id: education_activity.id, id: 0, from_review: 1, from_edit: 1 }
      expected = review_activities_flow_education_path(id: education_activity, from_edit: 1)
      expect(Capybara.string(response.body)).to have_css(".back-nav__link[href='#{expected}']")
    end

    it "month 1 back goes to review with from_edit" do
      get :edit, params: { education_id: education_activity.id, id: 1, from_review: 1, from_edit: 1 }
      expected = review_activities_flow_education_path(id: education_activity, from_edit: 1)
      expect(Capybara.string(response.body)).to have_css(".back-nav__link[href='#{expected}']")
    end
  end
end

RSpec.describe Activities::DocumentUploadsController, type: :controller do
  include_context "activity_hub"

  render_views

  let(:activity_flow) do
    create(:activity_flow,
      volunteering_activities_count: 0,
      job_training_activities_count: 0,
      education_activities_count: 0,
      reporting_window_months: 2)
  end
  let(:education_activity) do
    create(:education_activity,
      activity_flow: activity_flow,
      data_source: :fully_self_attested,
      school_name: "Test University")
  end

  before do
    session[:flow_id] = activity_flow.id
    session[:flow_type] = :activity
  end

  # ── Creation flow ──

  describe "creation flow" do
    it "document uploads back goes to last month" do
      get :new, params: { education_id: education_activity.id }
      expected = edit_activities_flow_education_month_path(
        education_id: education_activity, id: 1)
      expect(Capybara.string(response.body)).to have_css(".back-nav__link[href='#{expected}']")
    end
  end
end
