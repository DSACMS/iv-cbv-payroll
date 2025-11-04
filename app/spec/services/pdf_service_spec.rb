require 'rails_helper'

RSpec.describe PdfService, type: :service do
  include PinwheelApiHelper
  include Cbv::AggregatorDataHelper
  include ApplicationHelper

  let(:current_time) { Date.parse('2024-06-18') }

  let(:cbv_flow) { create(:cbv_flow, :invited, :completed) }

  let(:pinwheel_report) { build(:pinwheel_report, :with_pinwheel_account) }
  let(:variables) do
    {
      is_caseworker: true,
      cbv_flow: cbv_flow,
      aggregator_report: pinwheel_report,
      has_consent: false,
      locale: :en
    }
  end


  describe "#generate" do
    around do |ex|
      I18n.with_locale(locale, &ex)
    end

    context "english locale" do
      let(:locale) { :en }
      it 'generates a PDF file' do
      pdf_service = PdfService.new(language: :en)
      @pdf_results = pdf_service.generate(
        renderer: ApplicationController.renderer,
        template: 'cbv/submits/show',
        variables: variables
      )
      expect(@pdf_results&.content).to include('%PDF-1.4')
      expect(@pdf_results&.html).to include('Gross pay YTD')
      expect(@pdf_results&.html).to include('Monthly summary')
      expect(@pdf_results&.html).to include('Agreement Consent Timestamp')
      expect(@pdf_results&.file_size).to be > 0
    end
    end


    context "spanish locale" do
      let(:locale) { :es }
      it 'generates a PDF file in english' do
      pdf_service = PdfService.new(language: :en)
      @pdf_results = pdf_service.generate(
              renderer: ApplicationController.renderer,
              template: 'cbv/submits/show',
              variables: variables
            )
      expect(@pdf_results&.content).to include('%PDF-1.4')
      expect(@pdf_results&.html).to include('Gross pay YTD')
      expect(@pdf_results&.html).to include('Agreement Consent Timestamp')
      expect(@pdf_results&.file_size).to be > 0
    end
    end

    context "with PA DHS agency" do
      let(:locale) { :en }
      let(:cbv_flow) { create(:cbv_flow, :invited, :completed, client_agency_id: 'pa_dhs') }
      let(:pinwheel_report) do
        build(:pinwheel_report, :with_pinwheel_account, paystubs: [
          Aggregators::ResponseObjects::Paystub.new(
            account_id: "account1",
            gross_pay_amount: 100000,
            net_pay_amount: 90000,
            gross_pay_ytd: 500000,
            pay_period_start: "2021-09-01",
            pay_period_end: "2021-09-15",
            pay_date: "2021-09-20",
            hours: 40,
            hours_by_earning_category: [ { category: "regular", hours: 40 } ],
            deductions: [ OpenStruct.new(category: "tax", amount: 10000, tax: "federal") ],
            earnings: [
              Aggregators::ResponseObjects::Earning.new(
                name: "Base Pay",
                category: "base",
                amount: 80000
              ),
              Aggregators::ResponseObjects::Earning.new(
                name: "Overtime Pay",
                category: "overtime",
                amount: 20000
              )
            ]
          )
        ])
      end

      it 'shows earnings list for PA DHS' do
        pdf_service = PdfService.new(language: :en)
        @pdf_results = pdf_service.generate(
          renderer: ApplicationController.renderer,
          template: 'cbv/submits/show',
          variables: variables
        )
        expect(@pdf_results&.html).to include('Gross pay line items')
        expect(@pdf_results&.html).to include('Gross Pay Item:')
      end
    end

    context "with non-PA DHS agency" do
      let(:locale) { :en }
      let(:cbv_flow) { create(:cbv_flow, :invited, :completed, client_agency_id: 'sandbox') }

      it 'does not show earnings list for sandbox' do
        pdf_service = PdfService.new(language: :en)
        @pdf_results = pdf_service.generate(
          renderer: ApplicationController.renderer,
          template: 'cbv/submits/show',
          variables: variables
        )
        expect(@pdf_results&.html).not_to include('Gross pay line items')
        expect(@pdf_results&.html).not_to include('Gross Pay Item:')
      end
    end
  end
end
