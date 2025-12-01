class Activities::BaseController < ApplicationController
  before_action :redirect_on_prod
  before_action :set_activity_flow

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
end
