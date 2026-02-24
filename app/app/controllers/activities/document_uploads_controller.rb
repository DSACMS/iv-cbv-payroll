class Activities::DocumentUploadsController < Activities::BaseController
  before_action :set_activity

  helper_method :upload_path

  def new
  end

  def create
    if params.exclude?(:activity)
      # User clicked the submit button without adding any files
      return redirect_to after_activity_path
    end

    if @activity.update(document_upload_params)
      redirect_to after_activity_path
    else
      render :new
    end
  end

  private

  def document_upload_params
    params.expect(activity: [ { document_uploads: [] } ])
  end

  def set_activity
    @activity = if params[:community_service_id]
                  @flow.volunteering_activities.find(params[:community_service_id])
                elsif params[:job_training_id]
                  @flow.job_training_activities.find(params[:job_training_id])
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
    else
      super
    end
  end

  def upload_path
    if params[:community_service_id]
      activities_flow_community_service_document_uploads_path(from_edit: params[:from_edit].presence)
    elsif params[:job_training_id]
      activities_flow_job_training_document_uploads_path
    else
      raise <<~ERROR
        No activity param matched in DocumentUploadsController#upload_path.
        Make sure to add it there if you're adding DocumentUploadable to a
        new activity type.
      ERROR
    end
  end
end
