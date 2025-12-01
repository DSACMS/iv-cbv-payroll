class Activities::ActivitiesController < Activities::BaseController
  skip_before_action :set_flow, only: [ :entry ]

  def index
    @volunteering_activities = @flow.volunteering_activities.order(created_at: :desc)
    @job_training_activities = @flow.job_training_activities.order(created_at: :desc)
  end

  def entry
    set_generic_flow
  end

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
