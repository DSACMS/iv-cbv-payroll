module MonthlyHoursInput
  extend ActiveSupport::Concern

  included do
    before_action :set_hours_input_vars, only: %i[edit update]
  end

  def edit
  end

  def update
    if params[:no_hours] == "1"
      @activity_month.hours = 0
    else
      @activity_month.hours = params.require(activity_month_param_key).permit(:hours)[:hours].to_i
    end

    if !valid_hours_submission?
      @error = true
      @activity_month.errors.add(:hours, I18n.t("#{hours_input_t_scope}.field_error"))
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

  # Subclasses must implement:
  # - hours_input_activity      → the parent activity record
  # - activity_month_param_key  → e.g. :volunteering_activity_month
  # - hours_input_path(month_index) → route helper for hours_input GET
  # - activity_display_name     → name shown in heading (org name, program name, etc.)
  # - hours_input_t_scope       → translation scope string
  # - hours_input_completed_notice → flash notice shown after all months are saved
  # - hours_input_completed_path (optional) → override to redirect somewhere other than after_activity_path
end
