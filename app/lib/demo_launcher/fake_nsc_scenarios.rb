# frozen_string_literal: true

module DemoLauncher
  module FakeNscScenarios
    UserProfile = Struct.new(
      :scenario_key,
      :first_name,
      :last_name,
      :date_of_birth,
      :enrollments,
      :terms,
      :coverage_months,
      keyword_init: true
    )

    USER_PROFILES = [
      UserProfile.new(
        scenario_key: "partial_enrollment_sam",
        first_name: "Sam",
        last_name: "Testuser",
        date_of_birth: Date.parse("1990-05-15"),
        enrollments: [
          { school_name: "Greenfield Community College", enrollment_status: :less_than_half_time },
          { school_name: "North Valley College", enrollment_status: :less_than_half_time }
        ]
      ),
      UserProfile.new(
        scenario_key: "partial_enrollment_multi_term",
        first_name: "Nina",
        last_name: "Testuser",
        date_of_birth: Date.parse("1990-05-15"),
        coverage_months: 2,
        terms: [
          { school_name: "Greenfield Community College", enrollment_status: :less_than_half_time },
          { school_name: "Riverside Technical Institute", enrollment_status: :less_than_half_time }
        ]
      ),
      UserProfile.new(
        scenario_key: "partial_enrollment_ziggy",
        first_name: "Ziggy",
        last_name: "Testuser",
        date_of_birth: Date.parse("1992-07-19"),
        enrollments: [
          { school_name: "Sunrise Community College", enrollment_status: :less_than_half_time }
        ]
      ),
      UserProfile.new(
        scenario_key: "partial_enrollment_casey",
        first_name: "Casey",
        last_name: "Testuser",
        date_of_birth: Date.parse("1991-04-22"),
        enrollments: [
          { school_name: "Pine Valley College", enrollment_status: :half_time },
          { school_name: "Riverside Community College", enrollment_status: :less_than_half_time }
        ]
      ),
      UserProfile.new(
        scenario_key: "partial_enrollment_taylor",
        first_name: "Taylor",
        last_name: "Testuser",
        date_of_birth: Date.parse("1994-03-08"),
        terms: [
          { school_name: "Harborview College", enrollment_status: :half_time, coverage_months: 1, coverage_position: :start },
          { school_name: "Harborview College", enrollment_status: :less_than_half_time }
        ]
      ),
      UserProfile.new(
        scenario_key: "partial_enrollment_maya",
        first_name: "Maya",
        last_name: "Testuser",
        date_of_birth: Date.parse("1993-09-11"),
        terms: [
          { school_name: "River College", enrollment_status: :less_than_half_time },
          { school_name: "River College", enrollment_status: :less_than_half_time }
        ]
      ),
      UserProfile.new(
        scenario_key: "summer_term_carryover_sage",
        first_name: "Sage",
        last_name: "Testuser",
        date_of_birth: Date.parse("1994-08-03"),
        terms: [
          {
            school_name: "Coastal State College",
            enrollment_status: :half_time,
            term_type: :qualifying_spring
          },
          {
            school_name: "Coastal State College",
            enrollment_status: :less_than_half_time,
            term_type: :summer_less_than_half_time
          }
        ]
      )
    ].freeze

    STATUS_CODES = {
      full_time: "F",
      three_quarter_time: "Q",
      half_time: "H",
      less_than_half_time: "L",
      enrolled: "Y"
    }.freeze

    module_function

    def scenario_keys
      USER_PROFILES.map(&:scenario_key)
    end

    def by_key(scenario_key)
      USER_PROFILES.find { |profile| profile.scenario_key == scenario_key }
    end

    def by_identity(identity)
      return nil unless identity

      USER_PROFILES.find do |profile|
        profile.first_name == identity.first_name &&
          profile.last_name == identity.last_name &&
          profile.date_of_birth == identity.date_of_birth
      end
    end

    def nsc_response_for(identity:, reporting_window:)
      profile = by_identity(identity)
      return nil unless profile

      enrollments = terms_for_profile(profile, reporting_window).map do |term|
        {
          "currentEnrollmentStatus" => "CC",
          "officialSchoolName" => term[:school_name],
          "nameOnSchoolRecord" => {
            "firstName" => profile.first_name,
            "middleName" => nil,
            "lastName" => profile.last_name
          },
          "enrollmentData" => [
            {
              "termBeginDate" => term[:term_begin].strftime("%Y-%m-%d"),
              "termEndDate" => term[:term_end].strftime("%Y-%m-%d"),
              "enrollmentStatus" => STATUS_CODES.fetch(term[:enrollment_status].to_sym)
            }
          ]
        }
      end

      { "enrollmentDetails" => enrollments }
    end

    def terms_for_profile(profile, reporting_window)
      if profile.terms.present?
        return profile.terms.map do |term_data|
          covered_window = covered_window_for_term_data(profile, reporting_window, term_data)
          {
            school_name: term_data[:school_name],
            enrollment_status: term_data[:enrollment_status],
            term_begin: covered_window.begin,
            term_end: covered_window.end
          }
        end
      end

      enrollments = profile.enrollments || []

      enrollments.map do |enrollment|
        {
          school_name: enrollment[:school_name],
          enrollment_status: enrollment[:enrollment_status],
          term_begin: reporting_window.begin,
          term_end: reporting_window.end
        }
      end
    end

    def covered_window_for_term_data(profile, reporting_window, term_data)
      case term_data[:term_type]&.to_sym
      when :qualifying_spring
        Date.new(reporting_window.begin.year, 3, 1)..Date.new(reporting_window.begin.year, 6, 15)
      when :summer_less_than_half_time
        Date.new(reporting_window.begin.year, 7, 1)..Date.new(reporting_window.begin.year, 8, 15)
      else
        covered_window_for_profile(
          profile,
          reporting_window,
          coverage_months: term_data[:coverage_months],
          coverage_position: term_data[:coverage_position]
        )
      end
    end

    def covered_window_for_profile(profile, reporting_window, coverage_months: nil, coverage_position: nil)
      months = coverage_months || profile.coverage_months
      return reporting_window unless months.present?

      if coverage_position&.to_sym == :start
        coverage_end = (reporting_window.begin + months.months - 1.day).end_of_month
        reporting_window.begin..[ coverage_end, reporting_window.end ].min
      else
        coverage_start = (reporting_window.end + 1.day - months.months).beginning_of_month
        [ coverage_start, reporting_window.begin ].max..reporting_window.end
      end
    end
  end
end
