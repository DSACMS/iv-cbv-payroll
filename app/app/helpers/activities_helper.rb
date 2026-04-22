module ActivitiesHelper
  def activity_hub_state(any_activities_added:, monthly_results:, required_month_count: monthly_results.length)
    return :empty unless any_activities_added

    complete_month_count = monthly_results.count(&:meets_requirements)
    complete_month_count >= required_month_count ? :completed : :in_progress
  end

  def activity_hub_title_key(state)
    case state
    when :empty
      "activities.hub.empty_state_title"
    when :completed
      "activities.hub.completed_state_title"
    else
      "activities.hub.in_progress_state_title"
    end
  end

  def activity_hub_description_key(state)
    case state
    when :completed
      "activities.hub.completed_state_description"
    else
      "activities.hub.in_progress_state_description"
    end
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
        edit_path: activities_flow_income_payment_details_path(user: { account_id: account.aggregator_account_id }, from_edit: 1)
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
      EducationActivityCardBuilder.new(
        activity: activity,
        reporting_months: reporting_months
      ).build
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
        edit_path: review_activities_flow_community_service_path(id: activity.id, from_edit: 1)
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
        edit_path: review_activities_flow_job_training_path(id: activity.id, from_edit: 1)
      }
    end
  end
end
