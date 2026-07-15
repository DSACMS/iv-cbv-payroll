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
      params.merge(household_launcher_overrides)
    )
    apply_household_launcher_overrides(flow)

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

  def household_launcher_overrides
    @household.launcher_overrides.with_indifferent_access
  end

  def apply_household_launcher_overrides(flow)
    return unless internal_environment?

    overrides = household_launcher_overrides

    flow.set_reporting_window_months!(overrides[:reporting_window_months]) if overrides[:reporting_window_months].present?
    flow.set_required_month_count!(overrides[:renewal_required_months]) if overrides[:renewal_required_months].present?
    flow.shift_reporting_window_start!(overrides[:reporting_window_start]) if overrides[:reporting_window_start].present?
    session[:launcher_timeout] = overrides[:launcher_timeout].to_i.minutes.to_i if overrides[:launcher_timeout].present?
  end

  def current_agency
    return agency_config[@household.client_agency_id] if @household

    super
  end
end
