class Cbv::OtherJobsController < Cbv::BaseController
  def show
  end

  def create
    redirect_to next_path
  end
end
