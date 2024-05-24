class HealthCheckController < ActionController::Base
  def ok
    head :ok
  end
end
