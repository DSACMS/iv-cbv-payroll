require "rails_helper"

RSpec.describe ActivityFlowProgressCalculator do
  describe "#overall_result" do
    subject(:result) { described_class.new(flow).overall_result }

    let(:flow) { create(:activity_flow, reporting_window_months: 1) }

    let(:first_month) { flow.reporting_window_range.begin }

    it "returns zero when no activities exist" do
      expect(result.total_hours).to eq(0)
    end

    it "sums volunteering hours and job training hours" do
      activity = create(:volunteering_activity, activity_flow: flow, organization_name: "Food Pantry")
      create(:volunteering_activity_month, volunteering_activity: activity, month: first_month, hours: 3)
      activity2 = create(:volunteering_activity, activity_flow: flow, organization_name: "Library")
      create(:volunteering_activity_month, volunteering_activity: activity2, month: first_month, hours: 2)
      create(:job_training_activity, activity_flow: flow, program_name: "Career Prep", organization_address: "123 Main St", hours: 5)

      expect(result.total_hours).to eq(10)
    end

    context "meets_requirements" do
      it "does not meet requirements when below 80 hours threshold" do
        create(:job_training_activity, activity_flow: flow, program_name: "Career Prep", organization_address: "123 Main St", hours: 79)

        expect(result.meets_requirements).to be(false)
      end

      it "meets requirements when month has at least 80 hours from volunteering and job training" do
        activity = create(:volunteering_activity, activity_flow: flow, organization_name: "Food Pantry")
        create(:volunteering_activity_month, volunteering_activity: activity, month: first_month, hours: 40)
        create(:job_training_activity, activity_flow: flow, program_name: "Career Prep", organization_address: "123 Main St", hours: 40)

        expect(result.meets_requirements).to be(true)
      end
    end

    context "meets_routing_requirements" do
      it "does not meet routing requirements when below 80 hours threshold" do
        create(:job_training_activity, activity_flow: flow, program_name: "Career Prep", organization_address: "123 Main St", hours: 79)

        expect(result.meets_routing_requirements).to be(false)
      end

      it "does not meet routing requirements when threshold met only via self-attested data" do
        education_activity = create(:education_activity, activity_flow: flow, status: "succeeded")
        create(:nsc_enrollment_term, education_activity: education_activity, enrollment_status: "less_than_half_time")
        create(:job_training_activity, activity_flow: flow, program_name: "Career Prep", organization_address: "123 Main St", hours: 80)

        expect(result.meets_routing_requirements).to be(false)
      end

      context "when threshold is met via validated data" do
        let(:flow) { create(:activity_flow, reporting_window_months: 1, volunteering_activities_count: 0, job_training_activities_count: 0, education_activities_count: 0) }

        before do
          education_activity = create(:education_activity, activity_flow: flow, status: "succeeded")
          create(:nsc_enrollment_term, education_activity: education_activity, enrollment_status: "half_time")
        end

        it "meets routing requirements" do
          expect(result.meets_routing_requirements).to be(true)
        end
      end
    end

    context "with multi-month reporting window" do
      let(:flow) { create(:activity_flow, reporting_window_months: 3) }
      let(:first_month) { flow.reporting_window_range.begin }
      let(:second_month) { first_month + 1.month }
      let(:third_month) { first_month + 2.months }

      it "does not meet requirements when any month has less than 80 hours" do
        create(:job_training_activity, activity_flow: flow, program_name: "Career Prep", organization_address: "123 Main St", hours: 240, date: first_month)

        expect(result.meets_requirements).to be(false)
      end

      it "meets requirements when each month has at least 80 hours" do
        create(:job_training_activity, activity_flow: flow, program_name: "Career Prep", organization_address: "123 Main St", hours: 80, date: first_month)
        create(:job_training_activity, activity_flow: flow, program_name: "Career Prep", organization_address: "123 Main St", hours: 80, date: second_month)
        create(:job_training_activity, activity_flow: flow, program_name: "Career Prep", organization_address: "123 Main St", hours: 80, date: third_month)

        expect(result.meets_requirements).to be(true)
      end

      it "meets requirements when volunteering hours and job training combine to reach threshold each month" do
        activity = create(:volunteering_activity, activity_flow: flow, organization_name: "Food Pantry")
        create(:volunteering_activity_month, volunteering_activity: activity, month: first_month, hours: 40)
        create(:volunteering_activity_month, volunteering_activity: activity, month: second_month, hours: 80)
        create(:volunteering_activity_month, volunteering_activity: activity, month: third_month, hours: 40)
        create(:job_training_activity, activity_flow: flow, program_name: "Career Prep", organization_address: "123 Main St", hours: 40, date: first_month)
        create(:job_training_activity, activity_flow: flow, program_name: "Career Prep", organization_address: "123 Main St", hours: 40, date: third_month)

        expect(result.meets_requirements).to be(true)
      end
    end

    context "with employment" do
      let(:progress) { described_class.new(flow).overall_result }

      context "derived from payroll report" do
        include PinwheelApiHelper

        # Fixture paystub has pay_date "2020-12-31" with 80 hours
        # Freeze to January 2021 so reporting_window covers December 2020
        let(:current_time) { Date.parse("2021-01-15") }
        let(:account_id) { "03e29160-f7e7-4a28-b2d8-813640e030d3" }

        let(:flow) do
          create(:activity_flow, reporting_window_months: 1, created_at: current_time)
        end

        let(:first_month) { flow.reporting_window_range.begin }

        before do
          create(:payroll_account, :pinwheel_fully_synced, flow: flow, aggregator_account_id: account_id)

          pinwheel_stub_request_end_user_paystubs_response
          pinwheel_stub_request_employment_info_response
          pinwheel_stub_request_income_metadata_response
          pinwheel_stub_request_identity_response
          pinwheel_stub_request_end_user_account_response
          pinwheel_stub_request_platform_response
          pinwheel_stub_request_shifts_response
        end

        around do |ex|
          Timecop.freeze(current_time, &ex)
        end

        it "includes employment hours in total hours" do
          # Fixture has 80 W2 hours + 45 gig hours in December 2020
          expect(progress.total_hours).to eq(125)
        end

        it "meets requirements when employment hours reach threshold" do
          # Fixture has 125 total hours (80 W2 + 45 gig)
          expect(progress.meets_requirements).to be(true)
        end

        it "combines employment hours with job training hours" do
          create(:job_training_activity, activity_flow: flow, program_name: "Career Prep", organization_address: "123 Main St", hours: 10, date: first_month)

          # 125 from fixture (80 W2 + 45 gig) + 10 from job training
          expect(progress.total_hours).to eq(135)
        end

        it "combines employment hours with volunteering hours" do
          activity = create(:volunteering_activity, activity_flow: flow, organization_name: "Food Pantry")
          create(:volunteering_activity_month, volunteering_activity: activity, month: first_month, hours: 10)

          # 125 from fixture (80 W2 + 45 gig) + 10 from volunteering
          expect(progress.total_hours).to eq(135)
        end
      end

      context "derived from mocked report" do
        let(:flow) { create(:activity_flow, reporting_window_months: 1) }
        let(:first_month) { flow.reporting_window_range.begin }
        let(:month_key) { first_month.strftime("%Y-%m") }
        let(:account_id) { "test-account-123" }

        let(:mock_report) { instance_double(Aggregators::AggregatorReports::AggregatorReport) }
        let(:mock_fetcher) { instance_double(AggregatorReportFetcher, report: mock_report) }

        before do
          create(:payroll_account, :pinwheel_fully_synced, flow: flow, aggregator_account_id: account_id)
          allow(AggregatorReportFetcher).to receive(:new).with(flow).and_return(mock_fetcher)
        end

        it "raises an error when payroll report has not been fetched" do
          allow(mock_report).to receive(:has_fetched?).and_return(false)

          expect { progress }.to raise_error("Payroll report not fetched")
        end

        it "includes W2 hours in total hours" do
          allow(mock_report).to receive_messages(has_fetched?: true, summarize_by_month: {
            account_id => {
              month_key => { total_w2_hours: 40.0, total_gig_hours: 0.0, accrued_gross_earnings: 0.0 }
            }
          })

          expect(progress.total_hours).to eq(40)
        end

        it "includes gig hours in total hours" do
          allow(mock_report).to receive_messages(has_fetched?: true, summarize_by_month: {
            account_id => {
              month_key => { total_w2_hours: 0.0, total_gig_hours: 25.0, accrued_gross_earnings: 0.0 }
            }
          })

          expect(progress.total_hours).to eq(25)
        end

        it "combines W2 and gig hours" do
          allow(mock_report).to receive_messages(has_fetched?: true, summarize_by_month: {
            account_id => {
              month_key => { total_w2_hours: 30.0, total_gig_hours: 20.0, accrued_gross_earnings: 0.0 }
            }
          })

          expect(progress.total_hours).to eq(50)
        end

        it "combines employment hours with job training hours" do
          create(:job_training_activity, activity_flow: flow, program_name: "Career Prep", organization_address: "123 Main St", hours: 10, date: first_month)

          allow(mock_report).to receive_messages(has_fetched?: true, summarize_by_month: {
            account_id => {
              month_key => { total_w2_hours: 40.0, total_gig_hours: 0.0, accrued_gross_earnings: 0.0 }
            }
          })

          expect(progress.total_hours).to eq(50)
        end

        it "combines employment hours with volunteering hours" do
          activity = create(:volunteering_activity, activity_flow: flow, organization_name: "Food Pantry")
          create(:volunteering_activity_month, volunteering_activity: activity, month: first_month, hours: 10)

          allow(mock_report).to receive_messages(has_fetched?: true, summarize_by_month: {
            account_id => {
              month_key => { total_w2_hours: 40.0, total_gig_hours: 0.0, accrued_gross_earnings: 0.0 }
            }
          })

          expect(progress.total_hours).to eq(50)
        end

        it "meets requirements when employment hours reach threshold" do
          allow(mock_report).to receive_messages(has_fetched?: true, summarize_by_month: {
            account_id => {
              month_key => { total_w2_hours: 80.0, total_gig_hours: 0.0, accrued_gross_earnings: 0.0 }
            }
          })

          expect(progress.meets_requirements).to be(true)
        end

        it "meets routing requirements when threshold met via validated employment data" do
          allow(mock_report).to receive_messages(has_fetched?: true, summarize_by_month: {
            account_id => {
              month_key => { total_w2_hours: 80.0, total_gig_hours: 0.0, accrued_gross_earnings: 0.0 }
            }
          })

          expect(progress.meets_routing_requirements).to be(true)
        end

        it "meets requirements when combined job training and employment hours reach threshold" do
          create(:job_training_activity, activity_flow: flow, program_name: "Career Prep", organization_address: "123 Main St", hours: 40, date: first_month)

          allow(mock_report).to receive_messages(has_fetched?: true, summarize_by_month: {
            account_id => {
              month_key => { total_w2_hours: 40.0, total_gig_hours: 0.0, accrued_gross_earnings: 0.0 }
            }
          })

          expect(progress.meets_requirements).to be(true)
        end

        it "meets requirements when combined volunteering hours and employment hours reach threshold" do
          activity = create(:volunteering_activity, activity_flow: flow, organization_name: "Food Pantry")
          create(:volunteering_activity_month, volunteering_activity: activity, month: first_month, hours: 40)

          allow(mock_report).to receive_messages(has_fetched?: true, summarize_by_month: {
            account_id => {
              month_key => { total_w2_hours: 40.0, total_gig_hours: 0.0, accrued_gross_earnings: 0.0 }
            }
          })

          expect(progress.meets_requirements).to be(true)
        end

        it "does not meet requirements when below threshold" do
          allow(mock_report).to receive_messages(has_fetched?: true, summarize_by_month: {
            account_id => {
              month_key => { total_w2_hours: 79.0, total_gig_hours: 0.0, accrued_gross_earnings: 0.0 }
            }
          })

          expect(progress.meets_requirements).to be(false)
        end

        context "with earnings threshold" do
          it "meets requirements when earnings reach threshold" do
            allow(mock_report).to receive_messages(has_fetched?: true, summarize_by_month: {
              account_id => {
                month_key => { total_w2_hours: 0.0, total_gig_hours: 0.0, accrued_gross_earnings: 580_00 }
              }
            })

            expect(progress.meets_requirements).to be(true)
          end

          it "does not meet requirements when earnings below threshold" do
            allow(mock_report).to receive_messages(has_fetched?: true, summarize_by_month: {
              account_id => {
                month_key => { total_w2_hours: 0.0, total_gig_hours: 0.0, accrued_gross_earnings: 579_00 }
              }
            })

            expect(progress.meets_requirements).to be(false)
          end

          it "meets requirements when hours below threshold but earnings above" do
            allow(mock_report).to receive_messages(has_fetched?: true, summarize_by_month: {
              account_id => {
                month_key => { total_w2_hours: 50.0, total_gig_hours: 0.0, accrued_gross_earnings: 600_00 }
              }
            })

            expect(progress.meets_requirements).to be(true)
          end

          it "meets routing requirements when threshold met via validated earnings only" do
            allow(mock_report).to receive_messages(has_fetched?: true, summarize_by_month: {
              account_id => {
                month_key => { total_w2_hours: 0.0, total_gig_hours: 0.0, accrued_gross_earnings: 580_00 }
              }
            })

            expect(progress.meets_routing_requirements).to be(true)
          end
        end

        context "with multi-month reporting window" do
          let(:flow) { create(:activity_flow, reporting_window_months: 3) }
          let(:first_month) { flow.reporting_window_range.begin }
          let(:second_month) { first_month + 1.month }
          let(:third_month) { first_month + 2.months }
          let(:first_month_key) { first_month.strftime("%Y-%m") }
          let(:second_month_key) { second_month.strftime("%Y-%m") }
          let(:third_month_key) { third_month.strftime("%Y-%m") }

          it "meets requirements when each month has at least 80 employment hours" do
            allow(mock_report).to receive_messages(has_fetched?: true, summarize_by_month: {
              account_id => {
                first_month_key => { total_w2_hours: 80.0, total_gig_hours: 0.0, accrued_gross_earnings: 0.0 },
                second_month_key => { total_w2_hours: 80.0, total_gig_hours: 0.0, accrued_gross_earnings: 0.0 },
                third_month_key => { total_w2_hours: 80.0, total_gig_hours: 0.0, accrued_gross_earnings: 0.0 }
              }
            })

            expect(progress.meets_requirements).to be(true)
          end

          it "does not meet requirements when one month is below threshold" do
            allow(mock_report).to receive_messages(has_fetched?: true, summarize_by_month: {
              account_id => {
                first_month_key => { total_w2_hours: 80.0, total_gig_hours: 0.0, accrued_gross_earnings: 0.0 },
                second_month_key => { total_w2_hours: 50.0, total_gig_hours: 0.0, accrued_gross_earnings: 0.0 },
                third_month_key => { total_w2_hours: 80.0, total_gig_hours: 0.0, accrued_gross_earnings: 0.0 }
              }
            })

            expect(progress.meets_requirements).to be(false)
          end

          it "combines job training and employment per month" do
            create(:job_training_activity, activity_flow: flow, program_name: "Career Prep", organization_address: "123 Main St", hours: 40, date: second_month)

            allow(mock_report).to receive_messages(has_fetched?: true, summarize_by_month: {
              account_id => {
                first_month_key => { total_w2_hours: 80.0, total_gig_hours: 0.0, accrued_gross_earnings: 0.0 },
                second_month_key => { total_w2_hours: 40.0, total_gig_hours: 0.0, accrued_gross_earnings: 0.0 },
                third_month_key => { total_w2_hours: 80.0, total_gig_hours: 0.0, accrued_gross_earnings: 0.0 }
              }
            })

            expect(progress.meets_requirements).to be(true)
          end

          it "combines volunteering hours and employment per month" do
            activity = create(:volunteering_activity, activity_flow: flow, organization_name: "Food Pantry")
            create(:volunteering_activity_month, volunteering_activity: activity, month: second_month, hours: 40)

            allow(mock_report).to receive_messages(has_fetched?: true, summarize_by_month: {
              account_id => {
                first_month_key => { total_w2_hours: 80.0, total_gig_hours: 0.0, accrued_gross_earnings: 0.0 },
                second_month_key => { total_w2_hours: 40.0, total_gig_hours: 0.0, accrued_gross_earnings: 0.0 },
                third_month_key => { total_w2_hours: 80.0, total_gig_hours: 0.0, accrued_gross_earnings: 0.0 }
              }
            })

            expect(progress.meets_requirements).to be(true)
          end

          it "meets requirements when each month has earnings above threshold" do
            allow(mock_report).to receive_messages(has_fetched?: true, summarize_by_month: {
              account_id => {
                first_month_key => { total_w2_hours: 0.0, total_gig_hours: 0.0, accrued_gross_earnings: 600_00 },
                second_month_key => { total_w2_hours: 0.0, total_gig_hours: 0.0, accrued_gross_earnings: 580_00 },
                third_month_key => { total_w2_hours: 0.0, total_gig_hours: 0.0, accrued_gross_earnings: 700_00 }
              }
            })

            expect(progress.meets_requirements).to be(true)
          end

          it "meets requirements with mix of hours and earnings across months" do
            allow(mock_report).to receive_messages(has_fetched?: true, summarize_by_month: {
              account_id => {
                first_month_key => { total_w2_hours: 80.0, total_gig_hours: 0.0, accrued_gross_earnings: 0 },
                second_month_key => { total_w2_hours: 0.0, total_gig_hours: 0.0, accrued_gross_earnings: 600_00 },
                third_month_key => { total_w2_hours: 80.0, total_gig_hours: 0.0, accrued_gross_earnings: 0 }
              }
            })

            expect(progress.meets_requirements).to be(true)
          end

          it "does not meet requirements when one month has neither hours nor earnings threshold" do
            allow(mock_report).to receive_messages(has_fetched?: true, summarize_by_month: {
              account_id => {
                first_month_key => { total_w2_hours: 80.0, total_gig_hours: 0.0, accrued_gross_earnings: 0 },
                second_month_key => { total_w2_hours: 50.0, total_gig_hours: 0.0, accrued_gross_earnings: 400_00 },
                third_month_key => { total_w2_hours: 80.0, total_gig_hours: 0.0, accrued_gross_earnings: 0 }
              }
            })

            expect(progress.meets_requirements).to be(false)
          end
        end
      end
    end
  end

  describe "#monthly_results" do
    subject(:result) { described_class.new(flow).monthly_results }

    let(:flow) { create(:activity_flow, reporting_window_months: 3) }
    let(:reporting_range_months) { flow.reporting_window_range.uniq(&:beginning_of_month) }

    it "returns empty results for all months when no activities exist" do
      expect(result).to contain_exactly(
        have_attributes(month: reporting_range_months.first, total_hours: 0, meets_requirements: false),
        have_attributes(month: reporting_range_months.second, total_hours: 0, meets_requirements: false),
        have_attributes(month: reporting_range_months.third, total_hours: 0, meets_requirements: false),
      )
    end

    context "when there are job training activities within the reporting range" do
      before do
        create(:job_training_activity, activity_flow: flow, program_name: "Career Prep", organization_address: "123 Main St", hours: 40, date: reporting_range_months.first + 1.day)
        create(:job_training_activity, activity_flow: flow, program_name: "Career Prep", organization_address: "123 Main St", hours: 40, date: reporting_range_months.first + 2.day)
        create(:job_training_activity, activity_flow: flow, program_name: "Career Prep", organization_address: "123 Main St", hours: 40, date: reporting_range_months.second + 1.day)
      end

      it "returns monthly results for those months" do
        expect(result).to contain_exactly(
          have_attributes(month: reporting_range_months.first, total_hours: 80, meets_requirements: true),
          have_attributes(month: reporting_range_months.second, total_hours: 40, meets_requirements: false),
          have_attributes(month: reporting_range_months.third, total_hours: 0, meets_requirements: false),
        )
      end
    end

    context "when there are volunteering hours within the reporting range" do
      before do
        activity = create(:volunteering_activity, activity_flow: flow, organization_name: "Food Pantry")
        create(:volunteering_activity_month, volunteering_activity: activity, month: reporting_range_months.first, hours: 80)
        create(:volunteering_activity_month, volunteering_activity: activity, month: reporting_range_months.second, hours: 40)
      end

      it "returns monthly results for those months" do
        expect(result).to contain_exactly(
          have_attributes(month: reporting_range_months.first, total_hours: 80, meets_requirements: true),
          have_attributes(month: reporting_range_months.second, total_hours: 40, meets_requirements: false),
          have_attributes(month: reporting_range_months.third, total_hours: 0, meets_requirements: false),
        )
      end
    end
  end

  describe "volunteering hours" do
    subject(:result) { described_class.new(flow).overall_result }

    context "with single-month reporting window" do
      let(:flow) { create(:activity_flow, reporting_window_months: 1) }
      let(:first_month) { flow.reporting_window_range.begin }

      it "includes volunteering_activity_months hours in total" do
        activity = create(:volunteering_activity, activity_flow: flow, organization_name: "Food Pantry")
        create(:volunteering_activity_month, volunteering_activity: activity, month: first_month, hours: 40)

        expect(result.total_hours).to eq(40)
      end

      it "sums hours across multiple volunteering activities" do
        activity1 = create(:volunteering_activity, activity_flow: flow, organization_name: "Food Pantry")
        activity2 = create(:volunteering_activity, activity_flow: flow, organization_name: "Library")
        create(:volunteering_activity_month, volunteering_activity: activity1, month: first_month, hours: 30)
        create(:volunteering_activity_month, volunteering_activity: activity2, month: first_month, hours: 20)

        expect(result.total_hours).to eq(50)
      end

      it "meets requirements when monthly hours reach threshold" do
        activity = create(:volunteering_activity, activity_flow: flow, organization_name: "Food Pantry")
        create(:volunteering_activity_month, volunteering_activity: activity, month: first_month, hours: 80)

        expect(result.meets_requirements).to be(true)
      end

      it "does not meet requirements when below threshold" do
        activity = create(:volunteering_activity, activity_flow: flow, organization_name: "Food Pantry")
        create(:volunteering_activity_month, volunteering_activity: activity, month: first_month, hours: 79)

        expect(result.meets_requirements).to be(false)
      end

      it "combines volunteering hours with job training hours" do
        activity = create(:volunteering_activity, activity_flow: flow, organization_name: "Food Pantry")
        create(:volunteering_activity_month, volunteering_activity: activity, month: first_month, hours: 40)
        create(:job_training_activity, activity_flow: flow, program_name: "Career Prep", organization_address: "123 Main St", hours: 40, date: first_month)

        expect(result.total_hours).to eq(80)
        expect(result.meets_requirements).to be(true)
      end
    end

    context "with multi-month reporting window" do
      let(:flow) { create(:activity_flow, reporting_window_months: 3) }
      let(:first_month) { flow.reporting_window_range.begin }
      let(:second_month) { first_month + 1.month }
      let(:third_month) { first_month + 2.months }

      it "meets requirements when each month has at least 80 hours" do
        activity = create(:volunteering_activity, activity_flow: flow, organization_name: "Food Pantry")
        create(:volunteering_activity_month, volunteering_activity: activity, month: first_month, hours: 80)
        create(:volunteering_activity_month, volunteering_activity: activity, month: second_month, hours: 80)
        create(:volunteering_activity_month, volunteering_activity: activity, month: third_month, hours: 80)

        expect(result.meets_requirements).to be(true)
      end

      it "does not meet requirements when one month is below threshold" do
        activity = create(:volunteering_activity, activity_flow: flow, organization_name: "Food Pantry")
        create(:volunteering_activity_month, volunteering_activity: activity, month: first_month, hours: 80)
        create(:volunteering_activity_month, volunteering_activity: activity, month: second_month, hours: 40)
        create(:volunteering_activity_month, volunteering_activity: activity, month: third_month, hours: 80)

        expect(result.meets_requirements).to be(false)
      end

      it "assigns hours to the correct month" do
        activity = create(:volunteering_activity, activity_flow: flow, organization_name: "Food Pantry")
        create(:volunteering_activity_month, volunteering_activity: activity, month: second_month, hours: 50)

        flow.reload
        monthly_results = described_class.new(flow).monthly_results
        second_result = monthly_results.find { |r| r.month == second_month }
        first_result = monthly_results.find { |r| r.month == first_month }

        expect(second_result.total_hours).to eq(50)
        expect(first_result.total_hours).to eq(0)
      end

      it "sums across multiple activities per month" do
        activity1 = create(:volunteering_activity, activity_flow: flow, organization_name: "Food Pantry")
        activity2 = create(:volunteering_activity, activity_flow: flow, organization_name: "Library")
        create(:volunteering_activity_month, volunteering_activity: activity1, month: first_month, hours: 50)
        create(:volunteering_activity_month, volunteering_activity: activity2, month: first_month, hours: 30)

        monthly_results = described_class.new(flow).monthly_results
        first_result = monthly_results.find { |r| r.month == first_month }

        expect(first_result.total_hours).to eq(80)
      end
    end
  end

  describe "#reporting_months" do
    subject(:calculator) { described_class.new(flow) }

    let(:flow) { create(:activity_flow, reporting_window_months: 2) }

    around do |ex|
      Timecop.freeze(Date.parse("2026-01-01"), &ex)
    end

    it "gives the start of months prior to the reporting window" do
      expect(calculator.reporting_months).to contain_exactly(
        Date.new(2025, 12, 1),
        Date.new(2025, 11, 1)
      )
    end
  end

  describe "education progress" do
    subject(:progress) { described_class.new(flow).overall_result }

    let(:flow) { create(:activity_flow, reporting_window_months: 1, education_activities_count: 0) }
    let(:education_activity) { create(:education_activity, activity_flow: flow, status: "succeeded") }

    before { education_activity }

    context "when education has half_time or above enrollment for the month" do
      before do
        create(:nsc_enrollment_term, education_activity: education_activity, enrollment_status: "half_time")
      end

      it "adds 80 hours to total" do
        expect(progress.total_hours).to eq(80)
      end

      it "meets requirements" do
        expect(progress.meets_requirements).to be(true)
      end
    end

    context "when education has less_than_half_time enrollment" do
      before do
        create(:nsc_enrollment_term, education_activity: education_activity, enrollment_status: "less_than_half_time")
      end

      it "adds 0 hours to total" do
        expect(progress.total_hours).to eq(0)
      end

      it "does not meet requirements" do
        expect(progress.meets_requirements).to be(false)
      end
    end

    context "when education sync has not succeeded" do
      let(:education_activity) { create(:education_activity, activity_flow: flow, status: "unknown") }

      before do
        create(:nsc_enrollment_term, education_activity: education_activity, enrollment_status: "full_time")
      end

      it "adds 0 hours to total" do
        expect(progress.total_hours).to eq(0)
      end
    end

    context "when combining education with job training" do
      before do
        create(:job_training_activity, activity_flow: flow, program_name: "Career Prep", organization_address: "123 Main St", hours: 20)
        create(:nsc_enrollment_term, education_activity: education_activity, enrollment_status: "half_time")
      end

      it "sums both activity types" do
        expect(progress.total_hours).to eq(100)
      end

      it "meets requirements" do
        expect(progress.meets_requirements).to be(true)
      end
    end

    context "when combining education with volunteering hours" do
      let(:first_month) { flow.reporting_window_range.begin }

      before do
        activity = create(:volunteering_activity, activity_flow: flow, organization_name: "Food Pantry")
        create(:volunteering_activity_month, volunteering_activity: activity, month: first_month, hours: 20)
        create(:nsc_enrollment_term, education_activity: education_activity, enrollment_status: "half_time")
      end

      it "sums both activity types" do
        expect(progress.total_hours).to eq(100)
      end

      it "meets requirements" do
        expect(progress.meets_requirements).to be(true)
      end
    end

    context "when combining volunteering and job training when education should not count" do
      let(:first_month) { flow.reporting_window_range.begin }

      before do
        activity = create(:volunteering_activity, activity_flow: flow, organization_name: "Food Pantry")
        create(:volunteering_activity_month, volunteering_activity: activity, month: first_month, hours: 20)
        create(:job_training_activity, activity_flow: flow, program_name: "Career Prep", organization_address: "123 Main St", hours: 20)
        create(:nsc_enrollment_term, education_activity: education_activity, enrollment_status: "less_than_half_time")
      end

      it "sums volunteering hours and job training but education hours are not awarded" do
        expect(progress.total_hours).to eq(40)
      end

      it "does not meet requirements when combined total is below threshold" do
        expect(progress.meets_requirements).to be(false)
      end
    end

    context "with multi-month reporting window" do
      let(:flow) { create(:activity_flow, reporting_window_months: 2, education_activities_count: 0) }
      let(:first_month) { flow.reporting_window_range.begin }
      let(:second_month) { first_month + 1.month }

      context "when enrollment covers both months with half_time or above" do
        before do
          create(:nsc_enrollment_term,
                 education_activity: education_activity,
                 enrollment_status: "full_time",
                 term_begin: first_month,
                 term_end: second_month.end_of_month)
        end

        it "adds 80 hours per month (160 total)" do
          expect(progress.total_hours).to eq(160)
        end

        it "meets requirements" do
          expect(progress.meets_requirements).to be(true)
        end
      end

      context "when enrollment only covers one month" do
        before do
          create(:nsc_enrollment_term,
                 education_activity: education_activity,
                 enrollment_status: "full_time",
                 term_begin: first_month,
                 term_end: first_month.end_of_month)
        end

        it "adds 80 hours for covered month only" do
          expect(progress.total_hours).to eq(80)
        end

        it "does not meet requirements (second month has 0 hours)" do
          expect(progress.meets_requirements).to be(false)
        end
      end
    end
  end
end
