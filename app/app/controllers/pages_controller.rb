class PagesController < ApplicationController
  def home
    unless params['format'].nil?
      redirect_to '/404'
    end
  end
end
