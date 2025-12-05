class Activities::BaseController < FlowController
  before_action :redirect_on_prod, :get_flow

  helper_method :next_path

  private

  def get_flow
    # Future tokenized link logic will go here? Below is copy-pasted from CBV::BaseController
    if session[flow_param]
      begin
        @flow = flow_class.find(session[flow_param])
      rescue ActiveRecord::RecordNotFound
        reset_cbv_session!
        redirect_to entry_path(cbv_flow_timeout: true)
      end
    else
      track_deeplink_without_cookie_event
      redirect_to entry_path(cbv_flow_timeout: true), flash: { slim_alert: { type: "info", message_html: t("cbv.error_missing_token_html") } }
    end
  end

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
