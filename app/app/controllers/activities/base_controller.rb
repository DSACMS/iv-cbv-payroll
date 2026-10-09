class Activities::BaseController < FlowController
  before_action :redirect_unless_activity_hub_enabled, :set_flow

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

  def redirect_if_nsc_disabled
    redirect_to new_activities_flow_education_path if nsc_disabled?
  end

  def after_activity_path
    return activities_flow_root_path if @flow.employment_focused?

    progress_result = progress_calculator.overall_result
    progress_result.meets_routing_requirements ? activities_flow_summary_path : activities_flow_root_path
  end

  # Loads the data needed to render the employment-focused review page
  # (app/views/activities/activities/employment_focused_review.html.erb).
  # Shared by Activities::ActivitiesController#index and
  # Activities::SummaryController#update, since the latter needs to
  # re-render this same page when consent validation fails for an
  # employment-focused flow, instead of falling back to the generic summary.
  def load_employment_focused_review_data
    @employment_payroll_accounts = @flow.payroll_accounts.published.order(created_at: :desc).select(&:sync_succeeded?)
    @employment_activities = @flow.employment_activities.published.includes(:employment_activity_months).order(created_at: :desc)
    @persisted_report = PersistedReportAdapter.new(@flow) if @employment_payroll_accounts.any?
  end

  def progress_calculator
    return nil unless @flow

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

  # Threads the from_edit/from_review navigation params (see the comment atop
  # each activity type controller) into every tracked event for the
  # controllers listed in activity_type_controller?, so call sites don't need
  # to pass them manually. Hub-level controllers (Hub, Entries, Submit,
  # Success, Summary) aren't in that list, since from_edit/from_review aren't
  # meaningful navigation context for them.
  def standard_track_attributes
    attrs = super
    return attrs unless activity_type_controller?

    attrs.merge(
      from_edit: params[:from_edit].presence,
      from_review: params[:from_review].presence
    )
  end

  def activity_type_controller?
    is_a?(Activities::EmploymentController) ||
      is_a?(Activities::EducationController) ||
      is_a?(Activities::JobTrainingController) ||
      is_a?(Activities::VolunteeringController) ||
      is_a?(Activities::DocumentUploadsController) ||
      is_a?(Activities::Employment::MonthSelectionsController) ||
      is_a?(Activities::Employment::MonthsController) ||
      is_a?(Activities::Education::MonthsController) ||
      is_a?(Activities::JobTraining::MonthsController) ||
      is_a?(Activities::Volunteering::MonthsController) ||
      is_a?(Activities::Education::TermCreditHoursController)
  end
end
