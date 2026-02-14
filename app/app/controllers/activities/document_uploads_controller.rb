class Activities::DocumentUploadsController < Activities::BaseController
  before_action :set_activity

  def new
  end

  def create
    if params.exclude?(:activity)
      redirect_to after_activity_path
    elsif @activity.update(document_upload_params)
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
    # TODO: Add all activity types here.
    @activity =
      case params[:activity_type].to_sym
      when :education
        @flow.education_activities.find(params[:activity_id])
      when :community_service
        @flow.volunteering_activities.find(params[:activity_id])
      end

    unless @activity.present?
      raise "No #{params[:activity_type]} activity found with ID #{params[:activity_id]} for the current flow"
    end
  end
end
