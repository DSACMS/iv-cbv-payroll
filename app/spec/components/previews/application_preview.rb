# frozen_string_literal: true

class ApplicationPreview < ViewComponent::Preview
  layout "component_preview"

  private

  def view_context
    @view_context ||= ActionController::Base.new.view_context.tap do |view_context|
      view_context.class.include(ApplicationHelper)
    end
  end
end
