# Query params used for navigation context:
#
#   from_edit   — "User entered from the hub's Edit button." Set only by the
#                 hub edit link. Threads through the flow so the review page
#                 shows "Save changes" and hides the back button.
#
#   from_review — "User clicked Edit on the review page to fix one thing."
#                 Set by edit links on the review page. Tells controllers to
#                 redirect back to review instead of advancing forward.
class Activities::VolunteeringController < Activities::BaseController
  include NavigationTracking

  before_action :set_volunteering_activity, only: %i[edit update destroy review save_review]
  before_action :set_back_url, only: %i[edit review]
  after_action :track_info_viewed_event, only: %i[new edit]
  after_action :track_review_viewed_event, only: :review

  def new
    @volunteering_activity = @flow.volunteering_activities.new
    track_event(TrackEvent::CommunityServiceFlowStarted)
  end

  def create
    @volunteering_activity = @flow.volunteering_activities.new(volunteering_activity_params.merge(draft: true))
    if @volunteering_activity.save
      track_event(TrackEvent::CommunityServiceInfoSubmitted, volunteering_activity_id: @volunteering_activity.id)
      redirect_to edit_activities_flow_community_service_month_path(community_service_id: @volunteering_activity, id: 0)
    else
      track_event(
        TrackEvent::CommunityServiceInfoValidationFailed,
        volunteering_activity_id: @volunteering_activity.id,
        error_fields: @volunteering_activity.errors.attribute_names.map(&:to_s)
      )
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @volunteering_activity.update(volunteering_activity_params)
      track_event(TrackEvent::CommunityServiceInfoSubmitted, volunteering_activity_id: @volunteering_activity.id)
      if params[:from_review].present?
        redirect_to review_activities_flow_community_service_path(id: @volunteering_activity, from_edit: params[:from_edit].presence)
      else
        redirect_to edit_activities_flow_community_service_month_path(
          community_service_id: @volunteering_activity,
          id: 0,
          from_edit: params[:from_edit].presence
        )
      end
    else
      track_event(
        TrackEvent::CommunityServiceInfoValidationFailed,
        volunteering_activity_id: @volunteering_activity.id,
        error_fields: @volunteering_activity.errors.attribute_names.map(&:to_s)
      )
      render :edit, status: :unprocessable_content
    end
  end

  def review
  end

  def save_review
    @volunteering_activity.update(review_params)
    publish_activity(@volunteering_activity, activity_type: :community_service)
    track_event(TrackEvent::CommunityServiceReviewSubmitted, volunteering_activity_id: @volunteering_activity.id)
    track_event(TrackEvent::CommunityServiceFlowCompleted, volunteering_activity_id: @volunteering_activity.id)
    redirect_to after_activity_path
  end

  def destroy
    @volunteering_activity.destroy

    redirect_to activities_flow_root_path
  end

  private

  def set_back_url
    if action_name == "edit" && params[:from_review].present?
      @back_url = review_activities_flow_community_service_path(
        id: @volunteering_activity,
        from_edit: params[:from_edit].presence
      )
    elsif action_name == "review" && params[:from_edit].blank?
      @back_url = new_activities_flow_community_service_document_upload_path(
        community_service_id: @volunteering_activity
      )
    end
  end

  def set_volunteering_activity
    @volunteering_activity = @flow.volunteering_activities.find(params[:id])
  end

  def review_params
    params.require(:volunteering_activity).permit(:additional_comments)
  end

  def volunteering_activity_params
    params.require(:volunteering_activity).permit(*VolunteeringActivity::FIELDS)
  end

  def track_info_viewed_event
    return unless response.successful?

    track_event(TrackEvent::CommunityServiceInfoViewed, volunteering_activity_id: @volunteering_activity.id)
  end

  def track_review_viewed_event
    return unless response.successful?

    track_event(TrackEvent::CommunityServiceReviewViewed, volunteering_activity_id: @volunteering_activity.id)
  end
end
