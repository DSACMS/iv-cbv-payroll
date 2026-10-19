require 'rails_helper'

RSpec.describe PdfService, type: :service do
  include PinwheelApiHelper
  include ApplicationHelper

  let(:current_time) { Date.parse('2024-06-18') }
  let(:cbv_flow) { create(:cbv_flow, :invited, :completed) }
  let(:pinwheel_report) { build(:pinwheel_report, :with_pinwheel_account) }
  let(:current_agency) { Rails.application.config.client_agencies["sandbox"] }

  describe "#generate" do
    around do |ex|
      I18n.with_locale(locale, &ex)
    end

    context "english locale" do
      let(:locale) { :en }

      it 'generates a PDF file' do
      pdf_service = described_class.new(language: :en)
      @pdf_results = pdf_service.generate(cbv_flow, pinwheel_report, current_agency)
      expect(@pdf_results&.content).to start_with('%PDF-')
      tag_roles = @pdf_results.content.scan(%r{/S\s*/([A-Za-z]+)}).flatten.uniq
      expect(tag_roles).to include("Caption")
      expect(@pdf_results&.html).to include('Test Agency')
      expect(@pdf_results&.html).to include('Gross pay YTD')
      expect(@pdf_results&.html).to include('Monthly summary')
      expect(@pdf_results&.html).to include('Agreement Consent Timestamp')
      expect(@pdf_results&.file_size).to be > 0
    end
    end


    context "spanish locale" do
      let(:locale) { :es }

      it 'generates a PDF file in english' do
      pdf_service = described_class.new(language: :en)
      @pdf_results = pdf_service.generate(cbv_flow, pinwheel_report, current_agency)
      expect(@pdf_results&.content).to start_with('%PDF-')
      expect(@pdf_results&.html).to include('Test Agency')
      expect(@pdf_results&.html).to include('Gross pay YTD')
      expect(@pdf_results&.html).to include('Agreement Consent Timestamp')
      expect(@pdf_results&.file_size).to be > 0
    end
    end
  end
end
