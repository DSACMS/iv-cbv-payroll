require 'rails_helper'

RSpec.describe Aggregators::Sdk::NscService, type: :service do
  subject(:service) { described_class.new(environment: :test, logger: logger) }

  let(:logger) { Logger.new(StringIO.new) }

  before do
    stub_const("Aggregators::Sdk::NscService::ENVIRONMENTS", {
      test: {
        base_url: "http://fake-nsc-api.local",
        token_url: "http://fake-nsc-api.local/token",
        client_id: "123",
        client_secret: "top-secret",
        account_id: "456",
        scope: "vs.api.insights"
      }
    })
  end

  describe "#fetch_enrollment_data" do
    let!(:token_request_stub) do
      nsc_stub_token_request
    end

    context "for Lynette, a user with enrollment details" do
      before do
        nsc_stub_request_education_search_response("lynette")
      end

      let(:user_lynette) do
        {
          first_name: "Lynnette",
          last_name: "Oyola",
          date_of_birth: "1988-10-24",
          as_of_date: Date.today
        }
      end

      it "returns response with enrollmentDetails for found student" do
        response = service.fetch_enrollment_data(**user_lynette)

        expect(response).to have_key("studentInfoProvided")
        expect(response).to have_key("enrollmentDetails")
      end

      context "when the OAuth token is expired" do
        let!(:education_search_stub) do
          nsc_stub_request_education_search_token_expired_response("lynette")
        end

        it "retries once after unauthorized" do
          result = service.fetch_enrollment_data(**user_lynette)

          expect(result).to include("transactionDetails")
          expect(token_request_stub).to have_been_requested
          expect(education_search_stub).to have_been_requested.twice
        end
      end

      context "when the server returns a 500 error" do
        it "raises an ApiError" do
          stub_request(:post, %r{#{Aggregators::Sdk::NscService::ENROLLMENT_ENDPOINT}})
            .to_return(status: 500, body: "", headers: {})

          expect { service.fetch_enrollment_data(**user_lynette) }
            .to raise_error(Aggregators::Sdk::NscService::ApiError)
        end
      end
    end

    context "for Linda, a user with no enrollment result" do
      before do
        nsc_stub_request_education_search_response("linda")
      end

      let(:user_linda) do
        {
          first_name: "Linda",
          last_name: "Cooper",
          date_of_birth: "1999-01-01",
          as_of_date: Date.today
        }
      end

      it "returns a response without enrollmentDetails" do
        response = service.fetch_enrollment_data(**user_linda)

        expect(response).to have_key("studentInfoProvided")
        expect(response).not_to have_key("enrollmentDetails")
      end
    end
  end

  describe "#shift_enrollment_dates_for_demo" do
    include NscApiHelper

    before do
      nsc_stub_token_request
    end

    context "when in demo mode" do
      before do
        allow(Rails.application.config).to receive(:demo_mode).and_return(true)
        allow(Rails.env).to receive(:development?).and_return(false)
      end

      context "for Lynette (one CC enrollment)" do
        before do
          nsc_stub_request_education_search_response("lynette")
        end

        it "shifts CC enrollment term dates to overlap with the previous month" do
          response = service.fetch_enrollment_data(
            first_name: "Lynnette", last_name: "Oyola",
            date_of_birth: "1988-10-24", as_of_date: Date.today
          )

          term = response["enrollmentDetails"].first["enrollmentData"].first
          term_end = Date.parse(term["termEndDate"])
          previous_month_range = (Date.today.beginning_of_month - 1.month)..Date.today.beginning_of_month.prev_day

          expect(previous_month_range).to cover(Date.today.beginning_of_month - 15.days)
          expect(term_end).to be >= previous_month_range.begin
        end

        it "preserves the term duration" do
          # Original: 2024-05-31 to 2024-11-19 = 172 days
          original_duration = Date.parse("2024-11-19") - Date.parse("2024-05-31")

          response = service.fetch_enrollment_data(
            first_name: "Lynnette", last_name: "Oyola",
            date_of_birth: "1988-10-24", as_of_date: Date.today
          )

          term = response["enrollmentDetails"].first["enrollmentData"].first
          shifted_duration = Date.parse(term["termEndDate"]) - Date.parse(term["termBeginDate"])

          expect(shifted_duration).to eq(original_duration)
        end

        it "preserves the enrollment status and structure" do
          response = service.fetch_enrollment_data(
            first_name: "Lynnette", last_name: "Oyola",
            date_of_birth: "1988-10-24", as_of_date: Date.today
          )

          expect(response["enrollmentDetails"].length).to eq(1)
          expect(response["enrollmentDetails"].first["currentEnrollmentStatus"]).to eq("CC")
          expect(response["enrollmentDetails"].first["enrollmentData"].first["enrollmentStatus"]).to eq("Y")
        end
      end

      context "for Rick (two CC enrollments at different schools)" do
        before do
          nsc_stub_request_education_search_response("rick_banas")
        end

        it "shifts dates for both CC enrollments by the same offset" do
          response = service.fetch_enrollment_data(
            first_name: "Rick", last_name: "Banas",
            date_of_birth: "1979-08-18", as_of_date: Date.today
          )

          expect(response["enrollmentDetails"].length).to eq(2)

          # Both should still be CC
          response["enrollmentDetails"].each do |ed|
            expect(ed["currentEnrollmentStatus"]).to eq("CC")
          end

          # The original offset between the two term start dates should be preserved
          # Original: school1 starts 2024-06-19, school2 starts 2024-05-31 => 19 day difference
          term1_begin = Date.parse(response["enrollmentDetails"][0]["enrollmentData"].first["termBeginDate"])
          term2_begin = Date.parse(response["enrollmentDetails"][1]["enrollmentData"].first["termBeginDate"])
          expect((term1_begin - term2_begin).to_i).to eq(19)
        end
      end

      context "for Linda (no enrollments)" do
        before do
          nsc_stub_request_education_search_response("linda")
        end

        it "returns the response unchanged" do
          response = service.fetch_enrollment_data(
            first_name: "Linda", last_name: "Cooper",
            date_of_birth: "1999-01-01", as_of_date: Date.today
          )

          expect(response).not_to have_key("enrollmentDetails")
        end
      end

      context "for Dominique (CN enrollment, not currently enrolled)" do
        before do
          nsc_stub_request_education_search_response("dominique_ricardo")
        end

        it "does not shift dates for CN enrollments" do
          response = service.fetch_enrollment_data(
            first_name: "Dominique", last_name: "Ricardo",
            date_of_birth: "1978-01-12", as_of_date: Date.today
          )

          term = response["enrollmentDetails"].first["enrollmentData"].first
          expect(term["termBeginDate"]).to eq("2023-09-30")
          expect(term["termEndDate"]).to eq("2024-05-09")
        end
      end
    end

    context "when not in demo mode" do
      before do
        allow(Rails.application.config).to receive(:demo_mode).and_return(false)
        allow(Rails.env).to receive(:development?).and_return(false)
        nsc_stub_request_education_search_response("lynette")
      end

      it "does not modify any dates" do
        response = service.fetch_enrollment_data(
          first_name: "Lynnette", last_name: "Oyola",
          date_of_birth: "1988-10-24", as_of_date: Date.today
        )

        term = response["enrollmentDetails"].first["enrollmentData"].first
        expect(term["termBeginDate"]).to eq("2024-05-31")
        expect(term["termEndDate"]).to eq("2024-11-19")
      end
    end
  end
end
