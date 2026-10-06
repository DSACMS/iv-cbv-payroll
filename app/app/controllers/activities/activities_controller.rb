class Activities::ActivitiesController < Activities::BaseController
  after_action :track_hub_viewed_event, only: :index

  def index
    if @flow.employment_focused? && !@flow.any_activities_added?
      return redirect_to activities_flow_income_add_your_work_path
    end

    unless @flow.identity
      @flow.identity = IdentityService.new(request, @flow.cbv_applicant).get_identity
      @flow.save
    end

    @community_service_activities = @flow.volunteering_activities.published.includes(:volunteering_activity_months).order(created_at: :desc)
    @community_service_draft_activities = @flow.volunteering_activities.pre_populated_drafts.includes(:volunteering_activity_months).order(created_at: :desc)
    @work_programs_activities = @flow.job_training_activities.published.includes(:job_training_activity_months).order(created_at: :desc)
    @work_programs_draft_activities = @flow.job_training_activities.pre_populated_drafts.includes(:job_training_activity_months).order(created_at: :desc)
    @education_activities = @flow.education_activities.published.includes(:education_activity_months, :nsc_enrollment_terms).order(created_at: :desc)
    @education_draft_activities = @flow.education_activities.pre_populated_drafts.includes(:education_activity_months).order(created_at: :desc)

    @employment_draft_activities = @flow.employment_activities.pre_populated_drafts.includes(:employment_activity_months).order(created_at: :desc)
    load_employment_focused_review_data

    render :employment_focused_review if @flow.employment_focused?
  end

  private

  def track_hub_viewed_event
    return unless response.successful?

    track_event(TrackEvent::HubViewed)
  end
end
