module HasActivityMonths
  extend ActiveSupport::Concern

  class_methods do
    # Sets up the activity_months alias for the type-specific association.
    # Usage: has_activity_months :volunteering_activity_months
    def has_activity_months(association_name)
      alias_method :activity_months, association_name
    end
  end
end
