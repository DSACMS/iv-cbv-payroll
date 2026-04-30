FactoryBot.define do
  factory :cbv_applicant do
    client_agency_id { "sandbox" }
    first_name { "Jane" }
    middle_name { "Sue" }
    last_name { "Doe" }
    date_of_birth { "03/19/1992" }
    snap_application_date { Date.current }

    # Instantiate the proper subclass:
    # @see https://stackoverflow.com/questions/57504422/how-to-make-factorybot-return-the-right-sti-sub-class
    initialize_with { CbvApplicant.sti_class_for(client_agency_id).new }

    trait :sandbox do
      client_agency_id { "sandbox" }
    end

    trait :la_ldh do
      client_agency_id { "la_ldh" }

      case_number do
        # TODO: Determine actual LA LDH case number format.
        8.times.map { rand(10) }.join
      end

      date_of_birth { Date.new(2000, 1, 1) }
      doc_id { "%08d" % rand(100_000_000) }
    end
  end
end
