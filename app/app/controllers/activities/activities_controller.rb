class Activities::ActivitiesController < Activities::BaseController
  skip_before_action :set_flow, only: [ :entry, :show ]

  def index
    @volunteering_activities = @flow.volunteering_activities.order(created_at: :desc)
    @job_training_activities = @flow.job_training_activities.order(created_at: :desc)
  end

  def show
    @flow = ActivityFlow.find_by(token: params[:token])
    unless @flow
      return redirect_to(root_url, alert: t("activities.errors.invalid_token"))
    end

    set_flow_session(@flow.id, flow_param)
    cookies.permanent.encrypted[:cbv_applicant_id] = @flow.cbv_applicant_id
    redirect_to activities_flow_root_path
  end

  def entry
    set_generic_flow
  end
end
