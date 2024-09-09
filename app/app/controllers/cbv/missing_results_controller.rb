class Cbv::MissingResultsController < Cbv::BaseController
  def show
    @has_pinwheel_account = @cbv_flow.pinwheel_accounts.any?
  end
end
