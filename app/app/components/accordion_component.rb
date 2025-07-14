# frozen_string_literal: true

class AccordionComponent < ViewComponent::Base
  attr_reader :base_id

  renders_one :title
  renders_many :accordion_items

  def initialize(id:, heading_level: 4, data_action: "", data_section_identifier: "", expanded: false)
    @base_id = id
    @heading_level = heading_level.to_i.clamp(1, 6)
    @data_action = data_action
    @data_section_identifier = data_section_identifier
    @expanded = expanded
  end
end
