# frozen_string_literal: true

class AccordionComponent < ViewComponent::Base
  attr_reader :base_id

  renders_one :title
  renders_many :accordion_items

  def initialize(id:, expanded: false)
    @base_id = id
    @expanded = expanded
  end
end
