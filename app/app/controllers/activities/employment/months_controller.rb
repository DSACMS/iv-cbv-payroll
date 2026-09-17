class Activities::Employment::MonthsController < Activities::BaseController
  before_action :set_employment_activity
  before_action :ensure_months_selected, only: %i[edit update]

  include MonthlyHoursInput

  before_action :set_back_url, only: %i[edit update]
  after_action :track_month_viewed_event, only: :edit
  after_action :track_month_submission_event, only: :update

  private

  def track_month_viewed_event
    return unless response.successful?

    track_event(
      TrackEvent::EmploymentMonthViewed,
      employment_activity_id: @employment_activity.id,
      month_index: @month_index,
      month: I18n.l(@current_month, format: :month_year)
    )
  end

  def track_month_submission_event
    return unless @activity_month.present?

    event = @error ? TrackEvent::EmploymentMonthValidationFailed : TrackEvent::EmploymentMonthSubmitted
    attributes = {
      employment_activity_id: @employment_activity.id,
      month_index: @month_index,
      month: I18n.l(@current_month, format: :month_year)
    }
    attributes[:error_fields] = %w[gross_income hours] if @error
    track_event(event, attributes)
  end

  def set_employment_activity
    @employment_activity = @flow.employment_activities.find(params[:employment_id])
  end

  def ensure_months_selected
    return if @employment_activity.months_to_report.any?

    redirect_to edit_activities_flow_income_employment_month_selection_path(
      employment_id: @employment_activity,
      from_edit: params[:from_edit].presence
    )
  end

  def set_hours_input_vars
    super
    @activity_month&.tap { |m| m.gross_income = nil if m.new_record? }
  end

  def assign_hours_submission_values
    month_params = hours_submission_params
    default_value = month_params.values.all?(&:blank?) ? nil : 0
    @activity_month.hours = month_params[:hours].presence || default_value
    @activity_month.gross_income = month_params[:gross_income].presence || default_value
  end

  def hours_submission_params
    params.require(activity_month_param_key).permit(:hours, :gross_income)
  end

  def add_hours_submission_errors
    # MonthlyHoursInput adds inline field errors by default; this screen uses only the alert.
  end

  def hours_input_activity
    @employment_activity
  end

  def hours_input_months
    @employment_activity.months_to_report
  end

  def activity_month_param_key
    :employment_activity_month
  end

  def hours_input_path(month_index, from_edit: nil)
    edit_activities_flow_income_employment_month_path(
      employment_id: @employment_activity, id: month_index, from_edit: from_edit.presence
    )
  end

  def hours_input_t_scope
    "activities.employment.hours_input"
  end

  def activity_display_name
    @employment_activity.employer_name
  end

  def set_back_url
    @back_url = if params[:from_review].present?
                  review_activities_flow_income_employment_path(
                    id: @employment_activity,
                    from_edit: params[:from_edit].presence
                  )
                elsif @month_index > 0
                  hours_input_path(@month_index - 1, from_edit: params[:from_edit].presence)
                elsif @employment_activity.requires_month_selection?
                  edit_activities_flow_income_employment_month_selection_path(
                    employment_id: @employment_activity,
                    from_edit: params[:from_edit].presence
                  )
                else
                  edit_activities_flow_income_employment_path(id: @employment_activity)
                end
  end

  def hours_input_completed_path
    if params[:from_review].present?
      review_activities_flow_income_employment_path(
        id: @employment_activity,
        from_edit: params[:from_edit].presence
      )
    else
      new_activities_flow_income_employment_document_upload_path(
        employment_id: @employment_activity.id,
        from_edit: params[:from_edit].presence
      )
    end
  end

  def valid_hours_submission?
    income = @activity_month.gross_income || 0
    hours = @activity_month.hours || 0
    income >= 0 && hours >= 0 && (income.positive? || hours.positive?)
  end
end
