class Activities::EmploymentController < Activities::BaseController
  before_action :set_employment_activity, only: %i[edit update]

  def new
    @employment_activity = @flow.employment_activities.new
  end

  def create
    @employment_activity = @flow.employment_activities.new(employment_activity_params)
    if @employment_activity.save
      redirect_to edit_activities_flow_income_employment_month_path(employment_id: @employment_activity, id: 0)
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @employment_activity.update(employment_activity_params)
      redirect_to edit_activities_flow_income_employment_month_path(employment_id: @employment_activity, id: 0, from_edit: 1)
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  def set_employment_activity
    @employment_activity = @flow.employment_activities.find(params[:id])
  end

  def employment_activity_params
    params.require(:employment_activity).permit(
      :employer_name, :street_address, :street_address_line_2,
      :city, :state, :zip_code,
      :is_self_employed, :contact_name, :contact_email, :contact_phone_number
    )
  end
end
