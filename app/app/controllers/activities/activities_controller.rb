class Activities::ActivitiesController < ApplicationController
  def show
    @activities = VolunteeringActivity.all
  end
end
