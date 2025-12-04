# frozen_string_literal: true

# A ViewComponent that displays a synchronization status indicator with an icon and label.
#
# This component renders different visual states (in progress, succeeded, failed) with
# corresponding icons, colors, and styling based on the synchronization status.
#
# @example Basic usage with in_progress status
#   <%= render SynchronizationIndicatorComponent.new(status: :in_progress, label: "Employment") %>
#
# @example Succeeded status
#   <%= render SynchronizationIndicatorComponent.new(status: :succeeded, label: "Paystubs") %>
#
# @example Failed status
#   <%= render SynchronizationIndicatorComponent.new(status: :failed, label: "Hours") %>
class SynchronizationIndicatorComponent < ViewComponent::Base
  COMMON_ICON_CLASSES = %w[
    synchronizations-indicator__spinner
    usa-icon
    usa-icon--size-5
  ]
  SUCCEEDED_ICON_CLASSES = %w[
    text-white
    bg-primary
    border-primary
  ]

  IN_PROGRESS_ICON_CLASSES = %w[
    rotate
    border-base-light
  ]

  FAILED_ICON_CLASSES = %w[
    bg-base-darker
    text-white
    border-base-darker
  ]

  COMMON_LABEL_CLASSES = %w[
    margin-top-05
  ]

  IN_PROGRESS_LABEL_CLASSES = %w[
    text-thin
  ]

  SUCCEEDED_LABEL_CLASSES = %w[
    text-bold
    text-primary
  ]

  FAILED_LABEL_CLASSES = %w[
    text-bold
  ]

  IN_PROGRESS_ICON_VARIANT = "autorenew"
  SUCCEEDED_ICON_VARIANT = "check"
  FAILED_ICON_VARIANT = "priority_high"

  attr_reader :name

  # Initializes a new SynchronizationIndicatorComponent
  #
  # @param status [Symbol] the synchronization status - must be one of:
  #   - `:in_progress` - shows a rotating spinner icon
  #   - `:succeeded` - shows a checkmark icon
  #   - `:completed` - alias for `:succeeded`, shows a checkmark icon
  #   - `:failed` - shows an alert/priority icon
  # @param label [String] the text label to display below the icon
  #
  # @raise [ArgumentError] if status is not one of the valid values
  #
  # @return [SynchronizationIndicatorComponent]
  def initialize(status:, name: "")
    @name = name
    case status
    when :in_progress
      @svg_classes = COMMON_ICON_CLASSES | IN_PROGRESS_ICON_CLASSES
      @label_classes = COMMON_LABEL_CLASSES | IN_PROGRESS_LABEL_CLASSES
      @icon_variant = IN_PROGRESS_ICON_VARIANT
    when :succeeded, :completed
      @svg_classes = COMMON_ICON_CLASSES | SUCCEEDED_ICON_CLASSES
      @label_classes = COMMON_LABEL_CLASSES | SUCCEEDED_LABEL_CLASSES
      @icon_variant = SUCCEEDED_ICON_VARIANT
    when :failed
      @svg_classes = COMMON_ICON_CLASSES | FAILED_ICON_CLASSES
      @label_classes = COMMON_LABEL_CLASSES | FAILED_LABEL_CLASSES
      @icon_variant = FAILED_ICON_VARIANT
    else
      raise(ArgumentError)
    end
  end

  # Returns the CSS classes for the SVG icon as a space-separated string
  #
  # @return [String] space-separated CSS class names for the icon element
  def svg_classes
    @svg_classes.join(" ")
  end

  # Returns the CSS classes for the label as a space-separated string
  #
  # @return [String] space-separated CSS class names for the label element
  def label_classes
    @label_classes.join(" ")
  end

  # Returns the full asset path to the USWDS icon sprite with the appropriate icon variant
  #
  # @return [String] the asset path to the SVG sprite with fragment identifier
  def icon_variant
    asset_path("@uswds/uswds/dist/img/sprite.svg##{@icon_variant}")
  end
end
