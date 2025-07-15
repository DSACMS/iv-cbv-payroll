FactoryBot.define do
  factory :cbv_applicant do
    client_agency_id { "sandbox" }
    first_name { "Jane" }
    middle_name { "Sue" }
    last_name { "Doe" }
    date_of_birth {  "03/19/1992" }
    created_at { Date.current.strftime("%m/%d/%Y") }
    snap_application_date { Date.current.strftime("%m/%d/%Y") }

    # Instantiate the proper subclass:
    # @see https://stackoverflow.com/questions/57504422/how-to-make-factorybot-return-the-right-sti-sub-class
    initialize_with { CbvApplicant.sti_class_for(client_agency_id).new }

    trait :sandbox do
      client_agency_id { "sandbox" }
    end

    trait :az_des do
      client_agency_id { "az_des" }
      first_name { nil }
      middle_name { nil }
      last_name { nil }

      case_number do
        # TODO: Determine actual AZ DES case number format.
        8.times.map { rand(10) }.join
      end

      income_changes do
        [
          {
            change_index: 1,
            change_type: "Start",
            member_name: "Mark Scout",
            employer_name: "Walmart",
            effective_date: "2025-03-01",
            date_of_first_check: "2025-03-15",
            gross_amount_of_first_check: "600.00",
            gross_amount_per_check: "600.00",
            hourly_rate: "18.00",
            frequency: "Every Two Weeks",
            hours_per_week: "35",
            overtime: false,
            bonus: false,
            change_will_continue: false
          },
          {
            change_index: 2,
            change_type: "Stop",
            member_name: "Mark Scout",
            employer_name: "Target",
            effective_date: "2025-02-20"
          }
        ]
      end
    end

    trait :la_ldh do
      client_agency_id { "la_ldh" }

      case_number do
        # TODO: Determine actual LA LDH case number format.
        8.times.map { rand(10) }.join
      end

      date_of_birth { Date.new(2000, 1, 1) }
    end
  end
end
