class Activities::BaseController < FlowController
  before_action :redirect_on_prod
  before_action :set_generic_flow

  helper_method :next_path

  private

  def redirect_on_prod
    if Rails.env.production?
      redirect_to root_url
    end
  end

  def set_activity_flow
    @activity_flow = find_activity_flow || ActivityFlow.create!
    set_flow_session(@activity_flow.id, flow_param)
  end

  def find_activity_flow
    flow_id = session[cbv_flow_symbol]
    return unless flow_id

    ActivityFlow.find_by(id: flow_id)
  end

  def next_path
    case params[:controller]
    when "activities/activities"
      activities_flow_summary_path
    when "activities/summary"
      activities_flow_submit_path
    when "activities/submit"
      activities_flow_success_path
    end
  end

  def flow_class
    ActivityFlow
  end

  def flow_param
    :activity
  end
end
