class Activities::DocumentUploadsController < Activities::BaseController
  before_action :set_activity
  before_action :set_back_url, only: %i[new]
  after_action :track_employment_upload_viewed_event, only: :new
  after_action :track_education_upload_viewed_event, only: :new

  helper_method :upload_path, :remove_document_upload_path, :track_event_prefix

  def new
  end

  def create
    if params.exclude?(:activity)
      # User clicked the submit button without adding any files
      track_employment_upload_submitted_event
      track_education_upload_submitted_event
      return redirect_to after_activity_path
    end

    if @activity.update(document_upload_params)
      track_employment_upload_submitted_event
      track_education_upload_submitted_event
      redirect_to after_activity_path
    else
      render :new
    end
  end

  def destroy
    attachment = @activity.document_uploads_attachments.find(params[:id])
    blob = attachment.blob
    attachment.delete
    blob.destroy unless blob.attachments.exists?

    redirect_to upload_page_path
  end

  private

  def document_upload_params
    params.expect(activity: [ { document_uploads: [] } ])
  end

  def set_back_url
    last_month_index = progress_calculator.reporting_months.length - 1
    if params[:community_service_id]
      @back_url = edit_activities_flow_community_service_month_path(
        community_service_id: @activity,
        id: last_month_index,
        from_edit: params[:from_edit].presence
      )
    elsif params[:job_training_id]
      @back_url = edit_activities_flow_job_training_month_path(
        job_training_id: @activity,
        id: last_month_index,
        from_edit: params[:from_edit].presence
      )
    elsif params[:education_id]
      @back_url = edit_activities_flow_education_month_path(
        education_id: @activity,
        id: last_month_index,
        from_edit: params[:from_edit].presence
      )
    elsif params[:employment_id]
      @back_url = edit_activities_flow_income_employment_month_path(
        employment_id: @activity,
        id: last_month_index,
        from_edit: params[:from_edit].presence
      )
    end
  end

  def set_activity
    @activity = if params[:community_service_id]
                  @flow.volunteering_activities.find(params[:community_service_id])
                elsif params[:job_training_id]
                  @flow.job_training_activities.find(params[:job_training_id])
                elsif params[:education_id]
                  @flow.education_activities.find(params[:education_id])
                elsif params[:employment_id]
                  @flow.employment_activities.find(params[:employment_id])
                else
                  raise <<~ERROR
                    No activity param matched in DocumentUploadsController#set_activity.
                    Make sure to add it there if you're adding DocumentUploadable to a
                    new activity type.
                  ERROR
                end

    unless @activity.present?
      raise ActiveRecord::RecordNotFound.new("No activity found for the current flow.")
    end
  end

  def after_activity_path
    if params[:community_service_id]
      review_activities_flow_community_service_path(id: @activity, from_edit: params[:from_edit].presence)
    elsif params[:job_training_id]
      review_activities_flow_job_training_path(id: @activity, from_edit: params[:from_edit].presence)
    elsif params[:education_id]
      review_activities_flow_education_path(id: @activity, from_edit: params[:from_edit].presence)
    elsif params[:employment_id]
      review_activities_flow_income_employment_path(id: @activity, from_edit: params[:from_edit].presence)
    else
      super
    end
  end

  def upload_path
    if params[:community_service_id]
      activities_flow_community_service_document_uploads_path(from_edit: params[:from_edit].presence, from_review: params[:from_review].presence)
    elsif params[:job_training_id]
      activities_flow_job_training_document_uploads_path(from_edit: params[:from_edit].presence, from_review: params[:from_review].presence)
    elsif params[:education_id]
      activities_flow_education_document_uploads_path(from_edit: params[:from_edit].presence, from_review: params[:from_review].presence)
    elsif params[:employment_id]
      activities_flow_income_employment_document_uploads_path(from_edit: params[:from_edit].presence, from_review: params[:from_review].presence)
    else
      raise <<~ERROR
        No activity param matched in DocumentUploadsController#upload_path.
        Make sure to add it there if you're adding DocumentUploadable to a
        new activity type.
      ERROR
    end
  end

  def upload_page_path
    if params[:community_service_id]
      new_activities_flow_community_service_document_upload_path(
        community_service_id: @activity,
        from_edit: params[:from_edit].presence,
        from_review: params[:from_review].presence
      )
    elsif params[:job_training_id]
      new_activities_flow_job_training_document_upload_path(
        job_training_id: @activity,
        from_edit: params[:from_edit].presence,
        from_review: params[:from_review].presence
      )
    elsif params[:education_id]
      new_activities_flow_education_document_upload_path(
        education_id: @activity,
        from_edit: params[:from_edit].presence,
        from_review: params[:from_review].presence
      )
    elsif params[:employment_id]
      new_activities_flow_income_employment_document_upload_path(
        employment_id: @activity,
        from_edit: params[:from_edit].presence,
        from_review: params[:from_review].presence
      )
    else
      raise <<~ERROR
        No activity param matched in DocumentUploadsController#upload_page_path.
        Make sure to add it there if you're adding DocumentUploadable to a
        new activity type.
      ERROR
    end
  end

  def remove_document_upload_path(attachment)
    if params[:community_service_id]
      activities_flow_community_service_document_upload_path(
        community_service_id: @activity,
        id: attachment,
        from_edit: params[:from_edit].presence
      )
    elsif params[:job_training_id]
      activities_flow_job_training_document_upload_path(
        job_training_id: @activity,
        id: attachment,
        from_edit: params[:from_edit].presence
      )
    elsif params[:education_id]
      activities_flow_education_document_upload_path(
        education_id: @activity,
        id: attachment,
        from_edit: params[:from_edit].presence
      )
    elsif params[:employment_id]
      activities_flow_income_employment_document_upload_path(
        employment_id: @activity,
        id: attachment,
        from_edit: params[:from_edit].presence
      )
    else
      raise <<~ERROR
        No activity param matched in DocumentUploadsController#remove_document_upload_path.
        Make sure to add it there if you're adding DocumentUploadable to a
        new activity type.
      ERROR
    end
  end

  def track_event_prefix
    if params[:education_id]
      "Education"
    elsif params[:employment_id]
      "Employment"
    end
  end

  def track_employment_upload_viewed_event
    return unless params[:employment_id].present? && response.successful?

    track_event(TrackEvent::EmploymentDocumentUploadViewed, employment_activity_id: @activity.id)
  end

  def track_employment_upload_submitted_event
    return unless params[:employment_id].present?

    track_event(
      TrackEvent::EmploymentDocumentUploadSubmitted,
      employment_activity_id: @activity.id,
      document_count: @activity.document_uploads.count
    )
  end

  def track_education_upload_viewed_event
    return unless params[:education_id].present? && response.successful?

    track_event(TrackEvent::EducationDocumentUploadViewed, education_activity_id: @activity.id)
  end

  def track_education_upload_submitted_event
    return unless params[:education_id].present?

    track_event(
      TrackEvent::EducationDocumentUploadSubmitted,
      education_activity_id: @activity.id,
      document_count: @activity.document_uploads.count
    )
  end
end
