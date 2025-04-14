module Aggregators::FormatMethods::Pinwheel
  # See on Google Drive:
  # "Pinwheel Payroll Providers (Sandbox/Production) 2024-07-02"
  # "Mapping in Code" sheet
  #
  # We have to do this by matching employer_name because there is no employer
  # ID in any of the pinwheel endpoints.
  GIG_PLATFORM_NAMES = [
    "Airbnb (Host)", "Amazon Flex", "Bite Squad", "Care.com", "DoorDash (Dasher)",
    "Ebay (Seller)", "Etsy", "Field Agent", "GrubHub (Driver)", "Handy",
    "Instacart (Full Service Shopper)", "Lyft (Driver)", "OnlyFans",
    "Patreon (Freelancer)", "Poshmark (Seller)", "Postmates (Fleet)",
    "Roadie", "Shipt (Shopper)", "Shopify Store", "Thumbtack, Inc.",
    "Twitch", "Uber (Driver)", "Via (Driver)", "Wonolo"
  ]

  def self.hours(earnings)
    base_hours = earnings
      .filter { |e| e["category"] != "overtime" }
      .map { |e| e["hours"] }
      .compact
      .max
    return unless base_hours

    # Add overtime hours to the base hours, because they tend to be additional
    # work beyond the other entries. (As opposed to category="premium", which
    # often duplicates other earnings' hours.)
    #
    # See FFS-1773.
    overtime_hours = earnings
      .filter { |e| e["category"] == "overtime" }
      .sum { |e| e["hours"] || 0.0 }

    base_hours + overtime_hours
  end

  def self.hours_by_earning_category(earnings)
    earnings
      .filter { |e| e["hours"] && e["hours"] > 0 }
      .group_by { |e| e["category"] }
      .transform_values { |earnings| earnings.sum { |e| e["hours"] } }
  end

  def self.employment_type(employer_name)
    if GIG_PLATFORM_NAMES.include?(employer_name)
      :gig
    else
      :w2
    end
  end
end
