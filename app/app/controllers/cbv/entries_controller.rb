class Cbv::EntriesController < Cbv::BaseController
  def show
    I18n.locale = @cbv_flow.cbv_flow_invitation.language
  end
end
