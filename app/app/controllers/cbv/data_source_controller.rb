class Cbv::DataSourceController < Cbv::BaseController
  skip_forgery_protection
  skip_before_action :set_cbv_origin, :set_cbv_flow, :ensure_cbv_flow_not_yet_complete, :prevent_back_after_complete, :capture_page_view

  helper_method :source

  def source
    self.data_sources.find { |s| s.id == params[:source_id] }
  end

  def create
    Rails.logger.info params
    DataSourceChannel.broadcast_to(params[:cbv_flow_id], "hello")
  end
end
