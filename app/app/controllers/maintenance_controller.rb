class MaintenanceController < ApplicationController
  skip_before_action :redirect_if_maintenance_mode

  def show
  end
end
