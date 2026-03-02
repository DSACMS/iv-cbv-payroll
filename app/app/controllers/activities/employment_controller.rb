class Activities::EmploymentController < Activities::BaseController
  before_action :set_employment_activity, only: %i[edit update destroy review save_review]
  before_action :ensure_review_ready, only: %i[review save_review]

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

  def ensure_review_ready
    if @employment_activity.employer_name.blank?
      redirect_to edit_activities_flow_income_employment_path(@employment_activity)
      return
    end

    reporting_months = @flow.reporting_months
    reporting_months.each_with_index do |month, index|
      unless @employment_activity.employment_activity_months.exists?(month: month.beginning_of_month)
        redirect_to edit_activities_flow_income_employment_month_path(
          employment_id: @employment_activity, id: index
        )
        return
      end
    end
  end

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
