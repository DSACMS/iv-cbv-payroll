module MonthlyHoursInput
  extend ActiveSupport::Concern

  included do
    before_action :set_hours_input_vars, only: %i[edit update]
  end

  def edit
  end

  def update
    assign_hours_submission_values

    if !valid_hours_submission?
      @error = true
      add_hours_submission_errors
      render :edit, status: :unprocessable_content
      return
    end

    @activity_month.save!

    if params[:from_review].present?
      redirect_to hours_input_completed_path
    else
      next_index = @month_index + 1
      if next_index < @months.length
        redirect_to hours_input_path(next_index, from_edit: params[:from_edit].presence)
      else
        redirect_to hours_input_completed_path
      end
    end
  end

  private

  def assign_hours_submission_values
    if params[:no_hours] == "1"
      @activity_month.hours = 0
    else
      @activity_month.hours = hours_submission_params[:hours].to_i
    end
  end

  def hours_submission_params
    params.require(activity_month_param_key).permit(:hours)
  end

  def add_hours_submission_errors
    @activity_month.errors.add(:hours, I18n.t("#{hours_input_t_scope}.field_error"))
  end

  def set_hours_input_vars
    @months = progress_calculator.reporting_months
    @month_index = (params[:id] || 0).to_i

    if @month_index < 0 || @month_index >= @months.length
      redirect_to hours_input_path(0)
      return
    end

    @current_month = @months[@month_index]
    @activity_month = hours_input_activity.activity_months
      .find_or_initialize_by(month: @current_month.beginning_of_month)
    @activity_month.hours = nil if @activity_month.new_record?
  end

  def valid_hours_submission?
    hours = @activity_month.hours.to_i

    if @months.length == 1
      hours > 0
    elsif params[:from_review].present? || @month_index == @months.length - 1
      # Editing from review or last month: at least one month must have hours > 0
      hours_input_activity.activity_months.where.not(id: @activity_month.id).sum(:hours) + hours > 0
    else
      # Not the last month — any value (including 0) is fine
      true
    end
  end

  def hours_input_completed_path
    after_activity_path
  end

  # Including controllers must implement:
  # - hours_input_activity              → parent activity record
  # - activity_month_param_key           → e.g. :volunteering_activity_month
  # - hours_input_path(month_index)      → route helper for hours_input GET
  # - activity_display_name              → name shown in heading (org name, program name, etc.)
  # - hours_input_t_scope                → translation scope string
  # - hours_input_completed_path         → (optional) override to redirect elsewhere after completion
  #
  # Optional overrides for activity types that need more than hours (e.g. gross_income):
  # - assign_hours_submission_values     → set @activity_month from params (default: hours only)
  # - hours_submission_params            → permitted params (default: :hours)
  # - add_hours_submission_errors        → add validation errors (default: single :hours error)
end
