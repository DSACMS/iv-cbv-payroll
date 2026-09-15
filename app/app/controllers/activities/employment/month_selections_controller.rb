class Activities::Employment::MonthSelectionsController < Activities::BaseController
  before_action :set_employment_activity
  before_action :redirect_unless_tokenized_flow
  before_action :set_reporting_months

  def edit
    @selected_months = @employment_activity.months_to_report
  end

  def update
    @selected_months = selected_months_from_params

    if @selected_months.empty?
      @error = true
      render :edit, status: :unprocessable_content
      return
    end

    @employment_activity.transaction do
      @employment_activity.update!(selected_months: @selected_months)
      @employment_activity.employment_activity_months.where.not(month: @selected_months).destroy_all
    end

    redirect_to edit_activities_flow_income_employment_month_path(
      employment_id: @employment_activity,
      id: 0,
      from_edit: params[:from_edit].presence
    )
  end

  private

  def set_employment_activity
    @employment_activity = @flow.employment_activities.find(params[:employment_id])
  end

  def redirect_unless_tokenized_flow
    return if @flow.tokenized?

    redirect_to edit_activities_flow_income_employment_month_path(
      employment_id: @employment_activity,
      id: 0,
      from_edit: params[:from_edit].presence
    )
  end

  def set_reporting_months
    @reporting_months = @flow.reporting_months.map(&:beginning_of_month)
  end

  def selected_months_from_params
    submitted_months = month_selection_params.fetch(:selected_months, [])
    @reporting_months.select { |month| submitted_months.include?(month.iso8601) }
  end

  def month_selection_params
    params.require(:employment_activity).permit(selected_months: [])
  end
end
