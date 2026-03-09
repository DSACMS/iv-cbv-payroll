class Cbv::SynchronizationFailuresController < Cbv::BaseController
  def show
    @back_to_search_path = flow_navigator.income_sync_path(:employer_search)
  end
end
