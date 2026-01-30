# frozen_string_literal: true

class AccordionComponentPreview < ApplicationPreview
  def default
    render(AccordionComponent.new(id: "example")) do |accordion|
      accordion.with_title { "This is the accordion's title" }
      accordion.with_accordion_item { "Item 1" }
      accordion.with_accordion_item { "Item 2" }
    end
  end
end
