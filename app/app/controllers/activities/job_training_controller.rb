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
  include NavigationTracking

  before_action :set_job_training_activity, only: %i[edit update destroy review save_review]
  before_action :set_back_url, only: %i[edit review]

  after_action :track_info_viewed_event, only: %i[new edit]
  after_action :track_review_viewed_event, only: :review

  def new
    @job_training_activity = @flow.job_training_activities.new
  end

  def create
    @job_training_activity = @flow.job_training_activities.new(job_training_activity_params.merge(draft: true))
    if @job_training_activity.save
      track_info_submission
      redirect_to edit_activities_flow_job_training_month_path(job_training_id: @job_training_activity, id: 0)
    else
      track_info_validation_failed
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @job_training_activity.update(job_training_activity_params)
      track_info_submission
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
      track_info_validation_failed
      render :edit, status: :unprocessable_content
    end
  end

  def review
  end

  def save_review
    @job_training_activity.update(review_params)
    publish_activity(@job_training_activity, activity_type: :work_programs)
    track_event(TrackEvent::WorkProgramReviewSubmitted, job_training_activity_id: @job_training_activity.id)
    redirect_to after_activity_path
  end

  def destroy
    @job_training_activity.destroy

    redirect_to activities_flow_root_path
  end

  private

  def track_info_viewed_event
    return unless response.successful?

    track_event(TrackEvent::WorkProgramInfoViewed, job_training_activity_id: @job_training_activity&.id)
  end

  def track_review_viewed_event
    return unless response.successful?

    track_event(TrackEvent::WorkProgramReviewViewed, job_training_activity_id: @job_training_activity.id)
  end

  def track_info_submission
    track_event(TrackEvent::WorkProgramInfoSubmitted, job_training_activity_id: @job_training_activity.id)
  end

  def track_info_validation_failed
    track_event(
      TrackEvent::WorkProgramInfoValidationFailed,
      job_training_activity_id: @job_training_activity.id,
      error_fields: @job_training_activity.errors.attribute_names.map(&:to_s)
    )
  end

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
    params.require(:job_training_activity).permit(*JobTrainingActivity::FIELDS)
  end
end
