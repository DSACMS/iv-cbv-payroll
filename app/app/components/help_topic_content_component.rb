class HelpTopicContentComponent < ViewComponent::Base
  def initialize(topic:)
    @topic = topic
  end

  private

  attr_reader :topic
end 