class Activities::JobTrainingController < Activities::BaseController
  before_action :set_job_training_activity, only: %i[edit update destroy review save_review]

  def new
    @job_training_activity = @flow.job_training_activities.new
  end

  def create
    @job_training_activity = @flow.job_training_activities.new(job_training_activity_params)
    if @job_training_activity.save
      redirect_to edit_activities_flow_job_training_month_path(job_training_id: @job_training_activity, id: 0)
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @job_training_activity.update(job_training_activity_params)
      redirect_to edit_activities_flow_job_training_month_path(job_training_id: @job_training_activity, id: 0, from_edit: 1)
    else
      render :edit, status: :unprocessable_content
    end
  end

  def review
  end

  def save_review
    @job_training_activity.update(review_params)
    redirect_to after_activity_path
  end

  def destroy
    @job_training_activity.destroy

    redirect_to activities_flow_root_path
  end

  private

  def set_job_training_activity
    @job_training_activity = @flow.job_training_activities.find(params[:id])
  end

  def review_params
    params.require(:job_training_activity).permit(:additional_comments)
  end

  def job_training_activity_params
    params.require(:job_training_activity).permit(
      :program_name,
      :organization_name,
      :organization_address,
      :street_address,
      :street_address_line_2,
      :city,
      :state,
      :zip_code,
      :contact_name,
      :contact_email,
      :contact_phone_number
    )
  end
end
