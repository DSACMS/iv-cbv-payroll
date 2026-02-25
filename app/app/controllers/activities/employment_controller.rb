class Activities::EmploymentController < Activities::BaseController
  before_action :set_employment_activity, only: %i[edit update destroy review save_review]

  def new
    @employment_activity = @flow.employment_activities.new
  end

  def create
    @employment_activity = @flow.employment_activities.new(employment_activity_params)
    if @employment_activity.save
      redirect_to review_activities_flow_income_employment_path(id: @employment_activity)
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @employment_activity.update(employment_activity_params)
      redirect_to review_activities_flow_income_employment_path(id: @employment_activity, from_edit: 1)
    else
      render :edit, status: :unprocessable_content
    end
  end

  def review
  end

  def save_review
    @employment_activity.update(review_params)
    redirect_to after_activity_path
  end

  def destroy
    @employment_activity.destroy

    redirect_to activities_flow_root_path
  end

  private

  def set_employment_activity
    @employment_activity = @flow.employment_activities.find(params[:id])
  end

  def review_params
    params.require(:employment_activity).permit(:additional_comments)
  end

  def employment_activity_params
    params.require(:employment_activity).permit(
      :employer_name, :street_address, :street_address_line_2,
      :city, :state, :zip_code,
      :is_self_employed, :contact_name, :contact_email, :contact_phone_number
    )
  end
end
