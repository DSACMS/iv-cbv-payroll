require "factory_bot"
require Rails.root.join('spec/support/test_helpers')

class BaseMailerPreview < ActionMailer::Preview
  def initialize(*)
    if FactoryBot.factories.any?
      FactoryBot.reload
    else
      FactoryBot.find_definitions
    end

    super
  end
end
