class Activities::VolunteeringController < Activities::BaseController
  before_action :set_volunteering_activity, only: %i[edit update destroy hours_input save_hours]
  before_action :set_hours_input_vars, only: %i[hours_input save_hours]

  def new
    @volunteering_activity = @flow.volunteering_activities.new
  end

  def create
    @volunteering_activity = @flow.volunteering_activities.new(volunteering_activity_params)
    if @volunteering_activity.save
      destination = redirect_after_save(@volunteering_activity)
      redirect_to destination, notice: (destination == after_activity_path ? t("activities.community_service.created") : nil)
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @volunteering_activity.update(volunteering_activity_params)
      destination = redirect_after_save(@volunteering_activity)
      redirect_to destination, notice: (destination == after_activity_path ? t("activities.community_service.updated") : nil)
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @volunteering_activity.destroy

    redirect_to activities_flow_root_path, notice: t("activities.community_service.deleted")
  end

  def save_hours
    if params[:no_hours] == "1"
      @volunteering_activity_month.hours = 0
    else
      @volunteering_activity_month.hours = params.dig(:volunteering_activity_month, :hours)
    end

    if !valid_hours_submission?
      @error = true
      render :hours_input, status: :unprocessable_content
      return
    end

    @volunteering_activity_month.save!

    next_index = @month_index + 1
    if next_index < @months.length
      redirect_to hours_input_activities_flow_volunteering_path(id: @volunteering_activity, month_index: next_index)
    else
      redirect_to after_activity_path
    end
  end

  private

  def set_volunteering_activity
    @volunteering_activity = @flow.volunteering_activities.find(params[:id])
  end

  def set_hours_input_vars
    @months = progress_calculator.reporting_months
    @month_index = (params[:month_index] || 0).to_i
    @current_month = @months[@month_index]
    @volunteering_activity_month = @volunteering_activity.volunteering_activity_months
      .find_or_initialize_by(month: @current_month.beginning_of_month)
  end

  def valid_hours_submission?
    hours = @volunteering_activity_month.hours.to_i

    if @months.length == 1
      hours > 0
    elsif @month_index == @months.length - 1
      # Last month of multi-month: at least one month must have hours > 0
      @volunteering_activity.volunteering_activity_months.where.not(id: @volunteering_activity_month.id).sum(:hours) + hours > 0
    else
      # Not the last month — any value (including 0) is fine
      true
    end
  end

  # TODO: Remove — temporary redirect for testing hours_input flow
  def redirect_after_save(activity)
    if params[:redirect_to_hours_input]
      hours_input_activities_flow_volunteering_path(id: activity, month_index: 0)
    else
      after_activity_path
    end
  end

  def volunteering_activity_params
    params.require(:volunteering_activity).permit(:organization_name, :date, :hours)
  end
end
