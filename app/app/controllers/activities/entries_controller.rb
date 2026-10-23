class Activities::EntriesController < Activities::BaseController
  skip_before_action :set_flow

  def show
    if params[:token].present?
      set_flow
    elsif session[:flow_id].present? && session[:flow_type].to_s == "activity"
      set_flow
    else
      set_generic_flow
    end

    redirect_used_invitation_for_flow unless performed?
  end
end
