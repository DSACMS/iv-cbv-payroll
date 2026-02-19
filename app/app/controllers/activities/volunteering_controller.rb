class Activities::VolunteeringController < Activities::BaseController
  before_action :set_volunteering_activity, only: %i[edit update destroy review save_review]

  def new
    @volunteering_activity = @flow.volunteering_activities.new
  end

  def create
    @volunteering_activity = @flow.volunteering_activities.new(volunteering_activity_params)
    if @volunteering_activity.save
      redirect_to edit_activities_flow_volunteering_month_path(volunteering_id: @volunteering_activity, id: 0)
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @volunteering_activity.update(volunteering_activity_params)
      redirect_to edit_activities_flow_volunteering_month_path(volunteering_id: @volunteering_activity, id: 0, from_edit: 1)
    else
      render :edit, status: :unprocessable_content
    end
  end

  def review
  end

  def save_review
    @volunteering_activity.update(review_params)
    redirect_to after_activity_path
  end

  def destroy
    @volunteering_activity.destroy

    redirect_to activities_flow_root_path
  end

  private

  def set_volunteering_activity
    @volunteering_activity = @flow.volunteering_activities.find(params[:id])
  end

  def review_params
    params.require(:volunteering_activity).permit(:additional_comments)
  end

  def volunteering_activity_params
    params.require(:volunteering_activity).permit(
      :organization_name, :street_address, :street_address_line_2,
      :city, :state, :zip_code,
      :coordinator_name, :coordinator_email, :coordinator_phone_number
    )
  end
end
