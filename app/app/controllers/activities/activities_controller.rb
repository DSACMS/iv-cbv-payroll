class Activities::ActivitiesController < Activities::BaseController
  def show
    @volunteering_activities = @activity_flow.volunteering_activities.order(created_at: :desc)
    @job_training_activities = @activity_flow.job_training_activities.order(created_at: :desc)
    @activities = VolunteeringActivity.all
    if params[:alert]
      flash[:alert] = params[:alert]
    end

    @identity = current_identity
    @activities = VolunteeringActivity.all
  end
end
