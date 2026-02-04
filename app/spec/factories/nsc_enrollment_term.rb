FactoryBot.define do
  factory :nsc_enrollment_term do
    education_activity

    enrollment_status { "half_time" }
    school_name { "Test University" }
    first_name { "Test" }
    last_name { "Student" }

    after(:build) do |term|
      reporting_window = term.education_activity.activity_flow.reporting_window_range
      term.term_begin ||= reporting_window.begin
      term.term_end ||= reporting_window.end
    end
  end
end
