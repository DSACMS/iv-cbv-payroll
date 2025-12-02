class Activities::BaseController < ApplicationController
  before_action :redirect_on_prod
  before_action :set_activity_flow

  helper_method :next_path

  private

  def redirect_on_prod
    if Rails.env.production?
      redirect_to root_url
    end
  end

  def set_activity_flow
    @activity_flow = find_activity_flow || ActivityFlow.create!
    session[:activity_flow_id] = @activity_flow.id
  end

  def find_activity_flow
    flow_id = session[:activity_flow_id]
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
end
