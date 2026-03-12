class Activities::Employment::MonthsController < Activities::BaseController
  before_action :set_employment_activity

  include MonthlyHoursInput

  before_action :set_back_url, only: %i[edit update]

  private

  def set_employment_activity
    @employment_activity = @flow.employment_activities.find(params[:employment_id])
  end

  def set_hours_input_vars
    super
    @activity_month&.tap { |m| m.gross_income = nil if m.new_record? }
  end

  def assign_hours_submission_values
    if params[:no_hours] == "1"
      @activity_month.hours = 0
      @activity_month.gross_income = 0
    else
      month_params = hours_submission_params
      @activity_month.hours = month_params[:hours].to_i
      @activity_month.gross_income = month_params[:gross_income].to_i
    end
  end

  def hours_submission_params
    params.require(activity_month_param_key).permit(:hours, :gross_income)
  end

  def add_hours_submission_errors
    @activity_month.errors.add(:gross_income, I18n.t("#{hours_input_t_scope}.field_error_income"))
    @activity_month.errors.add(:hours, I18n.t("#{hours_input_t_scope}.field_error_hours"))
  end

  def hours_input_activity
    @employment_activity
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
                else
                  edit_activities_flow_income_employment_path(id: @employment_activity)
                end
  end

  def hours_input_completed_path
    review_activities_flow_income_employment_path(id: @employment_activity, from_edit: params[:from_edit].presence)
  end

  def valid_hours_submission?
    income = @activity_month.gross_income.to_i
    hours = @activity_month.hours.to_i

    if @months.length == 1
      income > 0 && hours > 0
    elsif params[:from_review].present? || @month_index == @months.length - 1
      other = hours_input_activity.activity_months.where.not(id: @activity_month.id)
      other.sum(:gross_income) + income > 0 && other.sum(:hours) + hours > 0
    else
      true
    end
  end
end
