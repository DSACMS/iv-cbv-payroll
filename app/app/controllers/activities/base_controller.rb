class Activities::BaseController < FlowController
  before_action :redirect_on_prod, :set_flow
  helper_method :next_path

  def current_identity
    IdentityService.new(params).call
  end

  private

  def redirect_on_prod
    if Rails.env.production?
      redirect_to root_url
    end
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

  def entry_path
    activities_flow_root_path
  end
end
