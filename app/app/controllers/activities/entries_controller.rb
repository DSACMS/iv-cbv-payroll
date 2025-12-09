class Activities::EntriesController < Activities::BaseController
  skip_before_action :set_flow

  def show
    set_generic_flow
  end

  def create
    if params["agreement"] == "1"
      redirect_to next_path
    else
      redirect_to(entry_path, flash: { alert: t("cbv.entries.create.error") })
    end
  end
end
