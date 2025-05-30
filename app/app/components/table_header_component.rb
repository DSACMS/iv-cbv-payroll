# frozen_string_literal: true

class TableHeaderComponent < ViewComponent::Base
  def initialize(colspan: 2)
    @colspan = colspan
  end
end
