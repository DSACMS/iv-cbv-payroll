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
  before_action :set_volunteering_activity, only: %i[edit update destroy review save_review]
  before_action :set_back_url, only: %i[edit review]

  def new
    @volunteering_activity = @flow.volunteering_activities.new
  end

  def create
    @volunteering_activity = @flow.volunteering_activities.new(volunteering_activity_params)
    if @volunteering_activity.save
      redirect_to edit_activities_flow_community_service_month_path(community_service_id: @volunteering_activity, id: 0)
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @volunteering_activity.update(volunteering_activity_params)
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
    params.require(:volunteering_activity).permit(
      :organization_name, :street_address, :street_address_line_2,
      :city, :state, :zip_code,
      :coordinator_name, :coordinator_email, :coordinator_phone_number
    )
  end
end
