class Activities::EntriesController < Activities::BaseController
  def show; end

  private

  def set_flow
    if params[:token].present? || (session[:flow_id].present? && session[:flow_type].to_s == "activity")
      super
    else
      set_generic_flow
    end
  end
end
