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

    # Set a nonblank `dismiss_key` to enable the Dismiss button and controller.
    # Dismissal is remembered in `sessionStorage` for the browser tab's session,
    # including reloads and navigation. Use a stable key for each alert; include
    # the flow ID when dismissal should apply only to that flow.
    #
    # To show this preview again, paste this JavaScript into the browser console:
    #
    # ```javascript
    # sessionStorage.removeItem("dismissible-alert:lookbook-dismissible-alert");
    # ```
    def dismissible
      render(Uswds::Alert.new(type: :info, slim: true, dismiss_key: "lookbook-dismissible-alert")) do
        "This informative alert stays dismissed for the rest of your browser session."
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
