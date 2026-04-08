class Activities::BaseController < FlowController
  before_action :redirect_on_prod, :set_flow, :recover_mismatched_flow

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

  ACTIVITY_PARAMS = {
    community_service_id: VolunteeringActivity,
    job_training_id: JobTrainingActivity,
    employment_id: EmploymentActivity,
    education_id: EducationActivity
  }.freeze

  # When multiple tabs are open, one tab can overwrite session[:flow_id],
  # causing other tabs to load the wrong flow. Recover by looking up the
  # activity from URL params and restoring the correct flow to the session.
  def recover_mismatched_flow
    return unless @flow

    activity_param_key = ACTIVITY_PARAMS.keys.find { |key| params[key] }
    return unless activity_param_key

    activity = ACTIVITY_PARAMS[activity_param_key].find_by(id: params[activity_param_key])

    # The activity was deleted (e.g. by cleanup in another tab) — return to hub.
    return redirect_to activities_flow_root_path unless activity

    # Activity belongs to the current session's flow — no mismatch.
    return if activity.activity_flow_id == @flow.id

    correct_flow = activity.activity_flow
    unless correct_flow.device_id == cookies.permanent.signed[:device_id]
      return redirect_to root_url(cbv_flow_timeout: true)
    end

    @flow = correct_flow
    @cbv_flow = correct_flow
    set_flow_session(correct_flow.id, :activity)
  end

  def redirect_on_prod
    return if Rails.env.development? || ENV["ACTIVITY_HUB_ENABLED"] == "true"

    redirect_to root_url
  end

  def after_activity_path
    progress_result = progress_calculator.overall_result
    progress_result.meets_routing_requirements ? activities_flow_summary_path : activities_flow_root_path
  end

  def progress_calculator
    return nil unless @flow

    @_progress_calculator ||= ActivityFlowProgressCalculator.new(@flow, exclude_activity: creating_activity_id)
  end

  def creating_activity_id
    creating = session[:creating_activity]
    return unless creating

    { class_name: creating["class_name"], id: creating["id"] }
  end

  def track_creating_activity(activity)
    destroy_tracked_creating_activity
    session[:creating_activity] = { "class_name" => activity.class.name, "id" => activity.id, "activity_flow_id" => activity.activity_flow_id }
  end

  def clear_creating_activity
    session.delete(:creating_activity)
  end

  def track_creating_payroll_account(aggregator_account_id)
    destroy_tracked_creating_payroll_account
    session[:creating_payroll_account] = { "aggregator_account_id" => aggregator_account_id, "flow_id" => @flow.id }
  end

  def clear_creating_payroll_account
    session.delete(:creating_payroll_account)
  end

  def destroy_tracked_creating_activity
    creating = session[:creating_activity]
    return unless creating

    activity_class = creating["class_name"].safe_constantize
    activity_class&.find_by(id: creating["id"])&.destroy
    session.delete(:creating_activity)
  end

  def destroy_tracked_creating_payroll_account
    creating = session[:creating_payroll_account]
    return unless creating

    PayrollAccount.find_by(aggregator_account_id: creating["aggregator_account_id"])&.destroy
    session.delete(:creating_payroll_account)
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
