# frozen_string_literal: true

class EducationTermDetailsComponent < ViewComponent::Base
  def initialize(activity:)
    @activity = activity
  end

  private

  attr_reader :activity
end
