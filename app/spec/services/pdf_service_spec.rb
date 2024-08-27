require 'rails_helper'

RSpec.describe PdfService, type: :service do

  describe '#generate_pdf' do
    include PinwheelApiHelper

    let(:payments) do
      load_relative_json_file('request_end_user_paystubs_response.json')['data']
    end

    # let(:parsed_payments) do
    #   helper.parse_payments(payments)
    # end

    let(:template) { 'cbv/summaries/show' }
    let(:cbv_flow) { create(:cbv_flow) }
    let(:employments) { [{ employer_name: "ACME Corp" }] }
    let(:incomes) { [{ pay_frequency: "bi-weekly" }] }
    let(:identities) { [{ full_name: "John Doe" }] }
    let(:variables) do
      {
        locals: {
          is_caseworker: false,
          cbv_flow: cbv_flow,
          payments: payments,
          employments: employments,
          incomes: incomes,
          identities: identities
        }
      }
    end
    let(:pdf_service) { PdfService.new }
    let(:file_path) { pdf_service.generate_pdf(template, variables) }

    before do
      allow(ApplicationController).to receive(:render).and_return("<html><body>Test PDF Content</body></html>")
      allow(WickedPdf).to receive_message_chain(:new, :pdf_from_string).and_return("PDF content")
    end

    it 'generates a PDF file' do
      expect(File).to exist(file_path)
    end

    it 'creates a file with .pdf extension' do
      expect(File.extname(file_path)).to eq('.pdf')
    end

    it 'creates a non-empty PDF file' do
      expect(File.size(file_path)).to be > 0
    end

    it 'renders the template with correct variables' do
      pdf_service.generate_pdf(template, variables)
      expect(ApplicationController).to have_received(:render).with(
        template: template,
        layout: "pdf",
        locals: variables[:locals]
      )
    end

    after do
      File.delete(file_path) if File.exist?(file_path)
    end
  end
end
