require "rails_helper"

RSpec.describe ActivityFlowProgressCalculator do
  describe "#overall_result" do
    subject(:result) { described_class.new(flow).overall_result }

    let(:flow) { create(:activity_flow, reporting_window_months: 1) }

    it "sums volunteering and job training hours" do
      create(:volunteering_activity, activity_flow: flow, organization_name: "Food Pantry", hours: 3)
      create(:volunteering_activity, activity_flow: flow, organization_name: "Library", hours: 2)
      create(:job_training_activity, activity_flow: flow, program_name: "Career Prep", organization_address: "123 Main St", hours: 5)

      expect(result.total_hours).to eq(10)
    end

    it "returns zero when no activities exist" do
      expect(result.total_hours).to eq(0)
    end

    it "does not meet requirements when month is below 80 hours" do
      create(:volunteering_activity, activity_flow: flow, organization_name: "Food Pantry", hours: 79)

      expect(result.meets_requirements).to be(false)
    end

    it "meets requirements when month has at least 80 hours" do
      create(:volunteering_activity, activity_flow: flow, organization_name: "Food Pantry", hours: 40)
      create(:job_training_activity, activity_flow: flow, program_name: "Career Prep", organization_address: "123 Main St", hours: 40)

      expect(result.meets_requirements).to be(true)
    end

    context "with multi-month reporting window" do
      let(:flow) { create(:activity_flow, reporting_window_months: 3) }
      let(:first_month) { flow.reporting_window_range.begin }
      let(:second_month) { first_month + 1.month }
      let(:third_month) { first_month + 2.months }

      it "does not meet requirements when any month has less than 80 hours" do
        create(:volunteering_activity, activity_flow: flow, hours: 240, date: first_month)

        expect(result.meets_requirements).to be(false)
      end

      it "meets requirements when each month has at least 80 hours" do
        create(:volunteering_activity, activity_flow: flow, hours: 80, date: first_month)
        create(:volunteering_activity, activity_flow: flow, hours: 80, date: second_month)
        create(:volunteering_activity, activity_flow: flow, hours: 80, date: third_month)

        expect(result.meets_requirements).to be(true)
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

    context "when there are activities within the reporting range" do
      before do
        create(:volunteering_activity, activity_flow: flow, hours: 40, date: reporting_range_months.first + 1.day)
        create(:volunteering_activity, activity_flow: flow, hours: 40, date: reporting_range_months.first + 2.day)
        create(:volunteering_activity, activity_flow: flow, hours: 40, date: reporting_range_months.second + 1.day)
      end

      it "returns monthly results for those months" do
        expect(result).to contain_exactly(
          have_attributes(month: reporting_range_months.first, total_hours: 80, meets_requirements: true),
          have_attributes(month: reporting_range_months.second, total_hours: 40, meets_requirements: false),
          have_attributes(month: reporting_range_months.third, total_hours: 0, meets_requirements: false),
        )
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

        it "combines employment hours with activity hours" do
          create(:volunteering_activity, activity_flow: flow, hours: 10, date: first_month)

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

        it "combines employment hours with activity hours" do
          create(:volunteering_activity, activity_flow: flow, hours: 10, date: first_month)

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

        it "meets requirements when combined activity and employment hours reach threshold" do
          create(:volunteering_activity, activity_flow: flow, hours: 40, date: first_month)

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

          it "combines activities and employment per month" do
            create(:volunteering_activity, activity_flow: flow, hours: 40, date: second_month)

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
end
