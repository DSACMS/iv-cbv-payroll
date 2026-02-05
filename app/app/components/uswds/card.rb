# frozen_string_literal: true

class Uswds::Card < ViewComponent::Base
  renders_one :header
  renders_one :media
  renders_one :body
  renders_one :footer

  def initialize(heading: nil, heading_level: 2, flag: false, media_right: false, header_first: false, **options)
    @heading = heading
    @heading_level = heading_level.to_i.clamp(1, 6)
    @flag = flag
    @media_right = media_right
    @header_first = header_first
    @options = options
  end

  private

  def card_classes
    classes = [ "usa-card" ]
    classes << "usa-card--flag" if @flag
    classes << "usa-card--header-first" if @header_first
    classes << "usa-card--media-right" if @media_right
    classes << @options[:class] if @options[:class]
    classes.join(" ")
  end
end
