module Cbv
  class HelpController < BaseController
    layout "help"

    def index
      @title = t("help.index.title")
    end

    def show
      @help_topic = params[:id].gsub('-', '_')
      @title = t("help.show.#{@help_topic}.title")
    end
  end
end
