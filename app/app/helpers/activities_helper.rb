module ActivitiesHelper
  def display_progress_indicator?(progress_calculator)
    progress_calculator.overall_result.total_hours > 0
  end

  def employment_cards(payroll_accounts, aggregator_report, reporting_range)
    return [] unless aggregator_report

    monthly_summaries = aggregator_report.summarize_by_month(
      from_date: reporting_range.begin,
      to_date: reporting_range.end
    )

    payroll_accounts.map do |account|
      account_report = aggregator_report.find_account_report(account.aggregator_account_id)
      employer_name = account_report&.employment&.employer_name || t("activities.employment.title")

      account_months = monthly_summaries[account.aggregator_account_id] || {}
      months = account_months
        .sort_by { |month_key, _| month_key }
        .reverse
        .map do |month_key, month_data|
          month_date = Date.parse("#{month_key}-01")
          {
            month: month_date,
            gross_earnings: month_data[:accrued_gross_earnings].to_i,
            hours: (month_data[:total_w2_hours].to_f + month_data[:total_gig_hours].to_f).round
          }
        end

      {
        name: employer_name,
        months: months,
        edit_path: activities_flow_income_payment_details_path(user: { account_id: account.aggregator_account_id })
      }
    end
  end

  def employment_activity_cards(activities)
    activities.map do |activity|
      months = activity.employment_activity_months.order(:month).map do |month|
        {
          month: month.month,
          gross_earnings: month.gross_income * 100,
          hours: month.hours
        }
      end
      {
        name: activity.employer_name,
        months: months,
        edit_path: review_activities_flow_income_employment_path(id: activity.id, from_edit: 1)
      }
    end
  end

  def combined_employment_card_data(reporting_range:, payroll_accounts:, persisted_report:, employment_activities:)
    employment_cards(payroll_accounts || [], persisted_report, reporting_range) +
      employment_activity_cards(employment_activities || [])
  end

  def education_cards(activities, reporting_months)
    activities.flat_map do |activity|
      if activity.fully_self_attested?
        fully_self_attested_education_cards(activity, reporting_months)
      else
        validated_education_cards(activity, reporting_months)
      end
    end
  end

  def community_service_cards(activities)
    activities.map do |activity|
      months = activity.volunteering_activity_months.order(:month).map do |vam|
        { month: vam.month, hours: vam.hours }
      end
      {
        name: activity.organization_name,
        months: months,
        edit_path: edit_activities_flow_community_service_path(id: activity.id)
      }
    end
  end

  def work_program_cards(activities)
    activities.map do |activity|
      months = activity.job_training_activity_months.order(:month).map do |activity_month|
        { month: activity_month.month, hours: activity_month.hours }
      end
      {
        name: activity.program_name,
        months: months,
        edit_path: edit_activities_flow_job_training_path(id: activity.id)
      }
    end
  end

  def enrollment_status_display(status)
    case status.to_sym
    when :full_time
      t("components.enrollment_term_table_component.status.full_time")
    when :three_quarter_time
      t("components.enrollment_term_table_component.status.three_quarter_time")
    when :half_time
      t("components.enrollment_term_table_component.status.half_time")
    when :less_than_half_time
      t("components.enrollment_term_table_component.status.less_than_half_time")
    when :enrolled
      t("components.enrollment_term_table_component.status.enrolled")
    else
      t("shared.not_applicable")
    end
  end

  private

  def validated_education_cards(activity, reporting_months)
    activity.nsc_enrollment_terms.map do |term|
      school_name = term.school_name&.titlecase || t("activities.education.title")
      months = reporting_months.reverse.map do |month_start|
        overlapping = term.overlaps_month?(month_start)
        show_credit_hours = overlapping && term.enrollment_less_than_half_time?
        if show_credit_hours
          partial_self_attested_month_data(activity: activity, term: term, month_start: month_start)
        else
          validated_month_data(term: term, month_start: month_start)
        end
      end

      {
        name: school_name,
        months: months,
        edit_path: if activity.partially_self_attested?
                     term_index = activity.less_than_half_time_terms_in_reporting_window
                       .index { |less_than_half_time_term| less_than_half_time_term.id == term.id } || 0
                     edit_activities_flow_education_term_credit_hour_path(education_id: activity.id, id: term_index)
                   else
                     edit_activities_flow_education_path(id: activity.id)
                   end
      }
    end
  end

  def fully_self_attested_education_cards(activity, reporting_months)
    months_by_date = activity.education_activity_months.index_by(&:month)
    months = reporting_months.reverse.map do |month_start|
      activity_month = months_by_date[month_start.beginning_of_month]
      self_attested_month_data(activity: activity, activity_month: activity_month, month_start: month_start)
    end

    [ {
      name: activity.school_name.presence || t("activities.education.title"),
      months: months,
      edit_path: edit_activities_flow_education_month_path(education_id: activity.id, id: 0, from_edit: 1)
    } ]
  end

  def education_credit_hours(activity_month)
    return 0 unless activity_month
    return activity_month.credit_hours.to_i if activity_month.has_attribute?(:credit_hours)
    activity_month.hours.to_i
  end

  def validated_month_data(term:, month_start:)
    overlapping = term.overlaps_month?(month_start)
    {
      month: month_start,
      enrollment_status: overlapping ? enrollment_status_display(term.enrollment_status) : t("activities.hub.cards.not_enrolled"),
      community_engagement_hours: overlapping && term.half_time_or_above? ? ActivityFlowProgressCalculator::PER_MONTH_HOURS_THRESHOLD : 0,
      credit_hours: nil,
      show_credit_hours: false
    }
  end

  def partial_self_attested_month_data(activity:, term:, month_start:)
    credit_hours = activity.review_term_credit_hours(term)
    {
      month: month_start,
      enrollment_status: enrollment_status_display(term.enrollment_status),
      community_engagement_hours: activity.community_engagement_hours(credit_hours),
      credit_hours: credit_hours,
      show_credit_hours: true
    }
  end

  def self_attested_month_data(activity:, activity_month:, month_start:)
    credit_hours = education_credit_hours(activity_month)
    {
      month: month_start,
      credit_hours: credit_hours,
      community_engagement_hours: activity.community_engagement_hours(credit_hours)
    }
  end
end
