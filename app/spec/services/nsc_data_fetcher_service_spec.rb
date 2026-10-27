require "rails_helper"

RSpec.describe NscDataFetcherService do
  include NscApiHelper

  subject(:service) do
    described_class.new(
      education_activity: education_activity,
      environment: :test,
      logger: logger,
      response_transformer: response_transformer
    )
  end

  let(:activity_flow) { create(:activity_flow, identity: identity, education_activities_count: 0) }
  let(:education_activity) { create(:education_activity, activity_flow: activity_flow) }
  let(:logger) { Logger.new(StringIO.new) }
  let(:response_transformer) { nil }

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


  describe "#fetch" do
    before do
      allow(Rails.application.config).to receive(:is_internal_environment).and_return(false)
      nsc_stub_token_request
    end

    context "when there are no enrollments (Linda)" do
      let(:identity) { create(:identity, :nsc_linda) }

      before do
        nsc_stub_request_education_search_response("linda")
      end

      it "updates the EducationActivity to have sync status = :no_enrollments" do
        expect { service.fetch }
          .to change { education_activity.reload.dup } # rubocop:disable RSpec/ExpectChange
          .from(have_attributes(status: "unknown"))
          .to(have_attributes(status: "no_enrollments"))
      end

      it "does not create any NscEnrollmentTerm's" do
        service.fetch

        expect(education_activity.nsc_enrollment_terms).to be_empty
      end

      it "does not change data_source" do
        service.fetch

        expect(education_activity.reload.data_source).to eq("validated")
      end
    end

    context "when there is one enrollment (Lynette)" do
      let(:identity) { create(:identity, :nsc_lynette) }

      before do
        education_activity.activity_flow.update!(created_at: Date.new(2024, 7, 15), reporting_window_months: 6)
        nsc_stub_request_education_search_response("lynette")
      end

      it "returns an EducationActivity with sync status = :succeeded" do
        expect { service.fetch }
          .to change { education_activity.reload.dup } # rubocop:disable RSpec/ExpectChange
          .from(have_attributes(status: "unknown"))
          .to(have_attributes(status: "succeeded"))
      end

      it "saves the enrollment details into an NscEnrollmentTerm" do
        service.fetch

        expect(education_activity.nsc_enrollment_terms.first)
          .to have_attributes(
            school_name: "Trident University International",
            enrollment_status: "enrolled", # Y
            term_begin: Date.parse("2024-05-31"),
            term_end: Date.parse("2024-11-19"),
            school_certified_on: Date.new(2024, 7, 16),
            nsc_withdrawn: false,
          )
      end

      it "sets data_source to partially_self_attested for enrolled (not half_time_or_above)" do
        service.fetch

        expect(education_activity.reload.data_source).to eq("partially_self_attested")
      end

      context "when the student has withdrawn" do
        before do
          nsc_stub_request_education_search_response("lynette") do |response|
            response["enrollmentDetails"].first["enrollmentData"].first["enrollmentStatus"] = "W"
          end
        end

        it "flags withdrawal while keeping the normalized status unknown" do
          service.fetch

          expect(education_activity.nsc_enrollment_terms.first).to have_attributes(
            enrollment_status: "unknown", nsc_withdrawn: true
          )
        end
      end

      context "when NSC returns an unrecognized status code" do
        before do
          nsc_stub_request_education_search_response("lynette") do |response|
            response["enrollmentDetails"].first["enrollmentData"].first["enrollmentStatus"] = "NEW"
          end
        end

        it "sets withdrawal to false without changing the existing unknown fallback" do
          service.fetch

          expect(education_activity.nsc_enrollment_terms.first).to have_attributes(
            enrollment_status: "unknown", nsc_withdrawn: false
          )
        end
      end

      context "when NSC omits the status code" do
        before do
          nsc_stub_request_education_search_response("lynette") do |response|
            response["enrollmentDetails"].first["enrollmentData"].first.delete("enrollmentStatus")
          end
        end

        it "keeps the normalized status unknown and defaults withdrawal to false" do
          service.fetch

          expect(education_activity.nsc_enrollment_terms.first).to have_attributes(
            enrollment_status: "unknown", nsc_withdrawn: false
          )
        end
      end

      it "queries NSC with the reporting window end date" do
        service.fetch

        expect(WebMock)
          .to have_requested(:post, nsc_enrollment_endpoint_pattern)
          .with(body: hash_including(
            "nscRequest" => hash_including("asOfDate" => activity_flow.reporting_window_range.max.strftime("%Y-%m-%d"))
          ))
      end
    end

    context "when enrollment records contain duplicates" do
      let(:identity) { create(:identity, :nsc_lynette) }
      let(:full_time_record) do
        {
          "termBeginDate" => "2021-09-01",
          "termEndDate" => "2021-12-01",
          "enrollmentStatus" => "F",
          "schoolCertifiedOnDate" => "2021-10-01",
          "anticipatedGraduationDate" => "2023-06-01"
        }
      end
      let(:older_full_time_record) do
        full_time_record.merge(
          "schoolCertifiedOnDate" => "2021-09-01",
          "anticipatedGraduationDate" => "2024-06-01"
        )
      end
      let(:withdrawn_record) do
        full_time_record.merge("enrollmentStatus" => "W", "schoolCertifiedOnDate" => "2021-11-01")
      end
      let(:enrollment_data) { [ withdrawn_record, full_time_record, older_full_time_record ] }
      let(:enrollment_details) do
        nsc_load_relative_json_file("lynette", "insight.json")["enrollmentDetails"].map do |detail|
          detail.merge("enrollmentData" => enrollment_data)
        end
      end

      before do
        activity_flow.update!(created_at: Date.new(2021, 12, 15), reporting_window_months: 3)
        nsc_stub_request_education_search_response("lynette") do |response|
          response["enrollmentDetails"] = enrollment_details
        end
      end

      it "saves the latest full-time record and the distinct withdrawal from the design example" do
        service.fetch

        expect(education_activity.nsc_enrollment_terms).to contain_exactly(
          have_attributes(
            term_begin: Date.new(2021, 9, 1), term_end: Date.new(2021, 12, 1),
            enrollment_status: "full_time", nsc_withdrawn: false, school_certified_on: Date.new(2021, 10, 1)
          ),
          have_attributes(
            term_begin: Date.new(2021, 9, 1), term_end: Date.new(2021, 12, 1),
            enrollment_status: "unknown", nsc_withdrawn: true, school_certified_on: Date.new(2021, 11, 1)
          )
        )
      end

      context "when the oldest record appears first" do
        let(:enrollment_data) { super().reverse }

        it "keeps the latest certification regardless of response order" do
          service.fetch

          expect(education_activity.nsc_enrollment_terms.pluck(:school_certified_on))
            .to contain_exactly(Date.new(2021, 10, 1), Date.new(2021, 11, 1))
        end
      end

      context "when another record has a different term start" do
        let(:enrollment_data) { super() + [ full_time_record.merge("termBeginDate" => "2021-08-01") ] }

        it "preserves the record with a distinct start date" do
          service.fetch

          expect(education_activity.nsc_enrollment_terms.pluck(:term_begin, :enrollment_status)).to contain_exactly(
            [ Date.new(2021, 9, 1), "full_time" ],
            [ Date.new(2021, 9, 1), "unknown" ],
            [ Date.new(2021, 8, 1), "full_time" ]
          )
        end
      end

      context "when another record has a different term end" do
        let(:enrollment_data) { super() + [ full_time_record.merge("termEndDate" => "2021-11-01") ] }

        it "preserves the record with a distinct end date" do
          service.fetch

          expect(education_activity.nsc_enrollment_terms.pluck(:term_end, :enrollment_status)).to contain_exactly(
            [ Date.new(2021, 12, 1), "full_time" ],
            [ Date.new(2021, 12, 1), "unknown" ],
            [ Date.new(2021, 11, 1), "full_time" ]
          )
        end
      end

      context "when another school reports the same terms" do
        let(:enrollment_details) do
          details = super()
          details + [ details.first.merge("officialSchoolName" => "Other College") ]
        end

        it "preserves each school's distinct enrollment records" do
          service.fetch

          expect(education_activity.nsc_enrollment_terms.pluck(:school_name, :enrollment_status)).to contain_exactly(
            [ "Trident University International", "full_time" ],
            [ "Trident University International", "unknown" ],
            [ "Other College", "full_time" ],
            [ "Other College", "unknown" ]
          )
        end
      end

      context "when duplicate terms appear in separate details for the same school" do
        let(:enrollment_details) do
          super().flat_map do |detail|
            detail["enrollmentData"].map { |record| detail.merge("enrollmentData" => [ record ]) }
          end
        end

        it "saves one record per distinct term and status for the school" do
          service.fetch

          expect(education_activity.nsc_enrollment_terms.pluck(:school_certified_on))
            .to contain_exactly(Date.new(2021, 10, 1), Date.new(2021, 11, 1))
        end
      end

      context "when duplicates have the same certification date" do
        let(:enrollment_data) do
          [ full_time_record, full_time_record.merge("anticipatedGraduationDate" => "2024-06-01") ]
        end

        it "saves one copy regardless of fields that are not displayed" do
          service.fetch

          expect(education_activity.nsc_enrollment_terms).to contain_exactly(
            have_attributes(enrollment_status: "full_time", school_certified_on: Date.new(2021, 10, 1))
          )
        end
      end
    end

    context "when there are multiple enrollments (Rick)" do
      let(:identity) { create(:identity, :nsc_rick) }

      before do
        education_activity.activity_flow.update!(created_at: Date.new(2024, 8, 1), reporting_window_months: 2)
        nsc_stub_request_education_search_response("rick_banas")
      end

      it "saves the enrollment details into multiple NscEnrollmentTerm's" do
        service.fetch

        expect(education_activity.nsc_enrollment_terms.count).to eq(2)
      end

      it "sets data_source to validated for half_time enrollment" do
        service.fetch

        expect(education_activity.reload.data_source).to eq("validated")
      end
    end

    context "when filtering by reporting window" do
      let(:identity) { create(:identity, :nsc_lynette) }

      it "saves terms that overlap with reporting window" do
        # Reporting window: 2024-02-01 to 2024-02-29
        # Term: 2024-01-01 to 2024-05-31 (spans entire window)
        education_activity.activity_flow.update!(created_at: Date.new(2024, 3, 1), reporting_window_months: 1)
        nsc_stub_request_education_search_response("lynette") do |response_data|
          response_data["enrollmentDetails"].first["enrollmentData"].first["termBeginDate"] = "2024-01-01"
          response_data["enrollmentDetails"].first["enrollmentData"].first["termEndDate"] = "2024-05-31"
        end

        service.fetch

        expect(education_activity.nsc_enrollment_terms.count).to eq(1)
      end

      it "excludes terms that do not overlap with reporting window" do
        # Reporting window: 2024-01-01 to 2024-03-31
        # Lynette's term: 2024-05-31 to 2024-11-19 (after window)
        education_activity.activity_flow.update!(created_at: Date.new(2024, 4, 1), reporting_window_months: 3)
        nsc_stub_request_education_search_response("lynette")

        service.fetch

        expect(education_activity.nsc_enrollment_terms.count).to eq(0)
        expect(education_activity.reload.status).to eq("succeeded")
      end
    end

    context "with a response transformer" do
      let(:identity) { create(:identity, :nsc_lynette) }
      let(:response_transformer) do
        lambda do |response|
          transformed = response.deep_dup
          transformed["enrollmentDetails"].first["enrollmentData"].first["termBeginDate"] = "2024-01-01"
          transformed["enrollmentDetails"].first["enrollmentData"].first["termEndDate"] = "2024-05-31"
          transformed
        end
      end

      before do
        education_activity.activity_flow.update!(created_at: Date.new(2024, 3, 1), reporting_window_months: 1)
        nsc_stub_request_education_search_response("lynette")
      end

      it "applies the transformed response before saving enrollment terms" do
        service.fetch

        term = education_activity.nsc_enrollment_terms.first
        expect(term.term_begin).to eq(Date.parse("2024-01-01"))
        expect(term.term_end).to eq(Date.parse("2024-05-31"))
      end
    end

    context "when the reporting window is shifted to overlap with fixture data" do
      context "for Lynette (one CC enrollment, term May 31 – Nov 19, 2024)" do
        let(:identity) { create(:identity, :nsc_lynette) }

        before do
          # Window: 2024-06-01..2024-11-30 — overlaps with Lynette's term
          education_activity.activity_flow.update!(created_at: Date.new(2024, 12, 1), reporting_window_months: 6)
          nsc_stub_request_education_search_response("lynette")
        end

        it "finds the enrollment term within the shifted window" do
          service.fetch

          term = education_activity.nsc_enrollment_terms.first
          expect(term).to be_present
          expect(term.term_begin).to eq(Date.parse("2024-05-31"))
          expect(term.term_end).to eq(Date.parse("2024-11-19"))
        end

        it "preserves the enrollment status and structure" do
          service.fetch

          expect(education_activity.nsc_enrollment_terms.count).to eq(1)
          expect(education_activity.nsc_enrollment_terms.first.enrollment_status).to eq("enrolled")
        end
      end

      context "for Rick (two CC enrollments at different schools, terms Jun–Nov 2024)" do
        let(:identity) { create(:identity, :nsc_rick) }

        before do
          # Window: 2024-06-01..2024-11-30 — overlaps with both of Rick's terms
          education_activity.activity_flow.update!(created_at: Date.new(2024, 12, 1), reporting_window_months: 6)
          nsc_stub_request_education_search_response("rick_banas")
        end

        it "finds both enrollment terms within the shifted window" do
          service.fetch

          terms = education_activity.nsc_enrollment_terms.order(:term_begin)
          expect(terms.count).to eq(2)

          # Original offset between term start dates is preserved
          # school2 starts 2024-05-31, school1 starts 2024-06-19 => 19 day difference
          expect((terms.last.term_begin - terms.first.term_begin).to_i).to eq(19)
        end
      end

      context "for Linda (no enrollments)" do
        let(:identity) { create(:identity, :nsc_linda) }

        before do
          nsc_stub_request_education_search_response("linda")
        end

        it "does not create any enrollment terms" do
          service.fetch

          expect(education_activity.nsc_enrollment_terms).to be_empty
        end
      end

      context "for Dominique (CN enrollment, not currently enrolled)" do
        let(:identity) { create(:identity, first_name: "Dominique", last_name: "Ricardo", date_of_birth: "1978-01-12") }

        before do
          nsc_stub_request_education_search_response("dominique_ricardo")
        end

        it "does not save CN enrollments even when window overlaps" do
          service.fetch

          expect(education_activity.reload.status).to eq("no_enrollments")
          expect(education_activity.nsc_enrollment_terms).to be_empty
        end
      end
    end
  end
end
