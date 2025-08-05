# frozen_string_literal: true

class ApplicationPreview < ViewComponent::Preview
  layout "component_preview"

  private

  # This is a simplified view context that includes the necessary helpers
  # for the UswdsFormBuilder to function correctly in previews.
  def view_context
    # Using ActionController::Base.new.view_context gives us a context
    # with all the standard Rails helpers loaded.
    @view_context ||= ActionController::Base.new.view_context.tap do |view_context|
      # We need to include our own ApplicationHelper to make methods like
      # `uswds_form_with`, `current_agency`, etc. available.
      view_context.class.include(ApplicationHelper)
    end
  end
end
