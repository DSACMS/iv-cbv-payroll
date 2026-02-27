class Activities::EmploymentController < Activities::BaseController
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

  private

  def employment_activity_params
    params.require(:employment_activity).permit(
      :employer_name, :street_address, :street_address_line_2,
      :city, :state, :zip_code,
      :is_self_employed, :contact_name, :contact_email, :contact_phone_number
    )
  end
end
