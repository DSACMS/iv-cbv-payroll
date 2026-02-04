class Activities::BaseController < FlowController
  before_action :redirect_on_prod, :set_flow

  helper_method :current_identity, :progress_calculator

  # Infer the `Identity` that is associated with the current request
  #
  # @return [Identity, nil] An Identity instance that may or may not
  #   already exist in the database. nil if no identity is associated
  #   with this request
  def current_identity
    @flow&.identity
  end

  # Infer the current {Identity} from this request and redirect back
  # to the activity hub if nil.
  #
  # @return [Identity]
  def current_identity!
    current_identity || redirect_to(
      activities_flow_root_path,
      flash: { alert: t("activities.error_no_identity") }
    )
  end

  private

  def redirect_on_prod
    return if Rails.env.development? || ENV["ACTIVITY_HUB_ENABLED"] == "true"

    redirect_to root_url
  end

  def after_activity_path
    progress_result = progress_calculator.result
    progress_result.meets_requirements ? activities_flow_summary_path : activities_flow_root_path
  end

  def progress_calculator
    @_progress_calculator ||= ActivityFlowProgressCalculator.new(@flow)
  end

  def flow_param
    :activity
  end

  def entry_path
    activities_flow_entry_path
  end

  def invitation_class
    ActivityFlowInvitation
  end

  def invalid_token_message
    t("activities.errors.invalid_token")
  end

  def track_invitation_clicked_event(invitation, flow)
    # No-op for activities currently
  end
end
