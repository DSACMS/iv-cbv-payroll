class PagesController < ApplicationController
  def home
    unless params["format"].nil?
      head 401, content_type: "text/html"
    end
  end
end
