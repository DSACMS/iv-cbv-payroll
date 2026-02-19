module MonthlyHoursInput
  extend ActiveSupport::Concern

  included do
    before_action :set_hours_input_vars, only: %i[hours_input save_hours]
  end

  def hours_input
  end

  def save_hours
    if params[:no_hours] == "1"
      @activity_month.hours = 0
    else
      @activity_month.hours = params.dig(activity_month_param_key, :hours)
    end

    if !valid_hours_submission?
      @error = true
      @activity_month.errors.add(:hours, I18n.t("#{hours_input_t_scope}.field_error"))
      render :hours_input, status: :unprocessable_content
      return
    end

    @activity_month.save!

    next_index = @month_index + 1
    if next_index < @months.length
      redirect_to hours_input_path(next_index)
    else
      redirect_to after_activity_path, notice: hours_input_completed_notice
    end
  end

  private

  def set_hours_input_vars
    @months = progress_calculator.reporting_months
    @month_index = (params[:month_index] || 0).to_i
    @current_month = @months[@month_index]
    @activity_month = hours_input_activity.activity_months
      .find_or_initialize_by(month: @current_month.beginning_of_month)
    @activity_month.hours = nil if @activity_month.new_record?
  end

  def valid_hours_submission?
    hours = @activity_month.hours.to_i

    if @months.length == 1
      hours > 0
    elsif @month_index == @months.length - 1
      # Last month of multi-month: at least one month must have hours > 0
      hours_input_activity.activity_months.where.not(id: @activity_month.id).sum(:hours) + hours > 0
    else
      # Not the last month — any value (including 0) is fine
      true
    end
  end

  # Subclasses must implement:
  # - hours_input_activity      → the parent activity record
  # - activity_month_param_key  → e.g. :volunteering_activity_month
  # - hours_input_path(month_index) → route helper for hours_input GET
  # - activity_display_name     → name shown in heading (org name, program name, etc.)
  # - hours_input_t_scope       → translation scope string
  # - hours_input_completed_notice → flash notice shown after all months are saved
end
