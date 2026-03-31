# Query params used for navigation context:
#
#   from_edit   — "User entered from the hub's Edit button." Set only by the
#                 hub edit link. Threads through the flow so the review page
#                 shows "Save changes" and hides the back button.
#
#   from_review — "User clicked Edit on the review page to fix one thing."
#                 Set by edit links on the review page. Tells controllers to
#                 redirect back to review instead of advancing forward.
class Activities::JobTrainingController < Activities::BaseController
  before_action :set_job_training_activity, only: %i[edit update destroy review save_review]
  before_action :set_back_url, only: %i[edit review]

  def new
    @job_training_activity = @flow.job_training_activities.new
  end

  def create
    @job_training_activity = @flow.job_training_activities.new(job_training_activity_params)
    if @job_training_activity.save
      track_creating_activity(@job_training_activity)
      redirect_to edit_activities_flow_job_training_month_path(job_training_id: @job_training_activity, id: 0)
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @job_training_activity.update(job_training_activity_params)
      if params[:from_review].present?
        redirect_to review_activities_flow_job_training_path(id: @job_training_activity, from_edit: params[:from_edit].presence)
      else
        redirect_to edit_activities_flow_job_training_month_path(
          job_training_id: @job_training_activity,
          id: 0,
          from_edit: params[:from_edit].presence
        )
      end
    else
      render :edit, status: :unprocessable_content
    end
  end

  def review
  end

  def save_review
    @job_training_activity.update(review_params)
    clear_creating_activity
    redirect_to after_activity_path
  end

  def destroy
    @job_training_activity.destroy

    redirect_to activities_flow_root_path
  end

  private

  def set_back_url
    if action_name == "edit" && params[:from_review].present?
      @back_url = review_activities_flow_job_training_path(
        id: @job_training_activity,
        from_edit: params[:from_edit].presence
      )
    elsif action_name == "review" && params[:from_edit].blank?
      @back_url = new_activities_flow_job_training_document_upload_path(
        job_training_id: @job_training_activity
      )
    end
  end

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
