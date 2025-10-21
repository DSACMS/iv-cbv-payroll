class Cbv::DataSourceController < Cbv::BaseController
  helper_method :source
  def source
    self.data_sources.find { |s| s.id == params[:source_id] }
  end
end
