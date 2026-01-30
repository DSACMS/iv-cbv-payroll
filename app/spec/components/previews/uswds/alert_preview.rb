# frozen_string_literal: true

module Uswds
  class AlertPreview < ApplicationPreview
    def info
      render(Uswds::Alert.new(type: :info)) do
        "This is a standard alert with supporting guidance."
      end
    end

    def success_with_heading
      render(Uswds::Alert.new(type: :success, heading: "Success")) do
        "We saved your updates and are ready for the next step."
      end
    end

    def warning_slim
      render(Uswds::Alert.new(type: :warning, slim: true)) do
        "Check the details below before continuing."
      end
    end

    def error_with_custom_class
      render(Uswds::Alert.new(type: :error, heading: "Action needed", class: "text-bold")) do
        "We could not process this request. Please try again."
      end
    end
  end
end
