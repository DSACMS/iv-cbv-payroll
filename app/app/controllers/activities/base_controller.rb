class Activities::BaseController < ApplicationController
  before_action :redirect_on_prod, :set_flow
  before_action :set_activity_flow

  helper_method :next_path, :current_identity

  # Infer the `Identity` that is associated with the current request
  #
  # @return [Identity, nil] An Identity instance that may or may not
  #   already exist in the database. nil if no identity is associated
  #   with this request
  def current_identity
    IdentityService.new(request).read_identity
  end

  # Save the current identity
  #
  # @return [Identity] the current identity
  def save_identity!
    IdentityService.new(request).save_identity(current_identity!)
  end

  # Infer the current {Identity} from this request and redirect back
  # to the activity hub if nil.
  #
  # @return [Identity]
  def current_identity!
    current_identity || redirect_to(
      activities_flow_root_path,
      flash: { alert: t("activities.education.error_no_identity") }
    )
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
