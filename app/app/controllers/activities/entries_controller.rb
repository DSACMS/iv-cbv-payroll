class Activities::EntriesController < Activities::BaseController
  skip_before_action :set_flow

  def show
    if params[:token].present?
      set_flow
    else
      set_generic_flow
    end
  end
end
