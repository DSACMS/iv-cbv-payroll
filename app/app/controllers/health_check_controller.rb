class HealthCheckController < ActionController::Base
  def ok
    render json: { status: "ok", version: ENV["IMAGE_TAG"] }
  end
end
