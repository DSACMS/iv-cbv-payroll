class HouseholdMembersController < ApplicationController
  before_action :redirect_unless_activity_hub_enabled, :set_household, :set_household_member

  def create
    # Completed household members should not re-enter an activity flow
    if @household_member.completed_activity_flow?
      set_flow_session(nil, :activity)
      return redirect_to household_start_path(token: @household.auth_token)
    end

    flow = ActivityFlow.resume_or_create_from_invitation(
      @household_member.activity_flow_invitation,
      cookies.permanent.signed[:device_id],
      params
    )

    set_flow_session(flow.id, :activity)
    redirect_to activities_flow_root_path
  end

  private

  def set_household
    @household = Household.find_by(auth_token: normalize_token(params[:token]))
    return if @household

    redirect_to root_url, flash: { alert: t("households.errors.invalid_token") }
  end

  def set_household_member
    @household_member = @household.household_members.find(params[:member_id])
  rescue ActiveRecord::RecordNotFound
    redirect_to household_start_path(token: @household.auth_token), flash: { alert: t("households.errors.invalid_member") }
  end

  def current_agency
    return agency_config[@household.client_agency_id] if @household

    super
  end
end
