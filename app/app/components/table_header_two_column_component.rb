# frozen_string_literal: true

class TableHeaderTwoColumnComponent < ViewComponent::Base
  def initialize(column1_title:, column2_title:)
    @column1_title = column1_title
    @column2_title = column2_title
  end
end
