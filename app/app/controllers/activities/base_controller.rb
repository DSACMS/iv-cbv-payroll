class Activities::BaseController < ApplicationController
  before_action :redirect_on_prod

  private

  def redirect_on_prod
    if Rails.env.production?
      redirect_to root_url
    end
  end
end
