class HouseholdsController < ApplicationController
  before_action :redirect_unless_activity_hub_enabled, :set_household
  after_action :track_household_selection_viewed, only: :show

  def show
    @household_members = @household.household_members.includes(:completed_activity_flows).order(:id)
    set_flow_session(nil, :activity)
  end

  private

  def track_household_selection_viewed
    return unless response.successful?

    track_event(
      TrackEvent::HouseholdSelectionViewed,
      household_member_count: @household_members.size,
      completed_member_count: @household_members.count(&:completed_activity_flow?)
    )
  end

  def set_household
    @household = Household.find_by(auth_token: normalize_token(params[:token]))
    return if @household

    redirect_to root_url, flash: { alert: t("households.errors.invalid_token") }
  end

  def current_agency
    return agency_config[@household.client_agency_id] if @household

    super
  end
end
