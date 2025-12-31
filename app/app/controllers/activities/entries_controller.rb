class Activities::EntriesController < Activities::BaseController
  skip_before_action :set_flow

  def show
    if params[:token].present?
      set_flow
    else
      set_generic_flow
    end
  end

  def create
    if params["agreement"] == "1"
      redirect_to next_path
    else
      flash.now[:alert] = t("activities.entry.consent_required")
      render :show, status: :unprocessable_content
    end
  end
end
