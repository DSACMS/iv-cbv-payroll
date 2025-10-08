require "pdf-reader"

class PdfService
  # Represents the result of PDF generation
  class PdfGenerationResult
    attr_reader :content, :html, :page_count, :file_size

    def initialize(content, html, page_count, file_size)
      @content = content
      @html = html
      @page_count = page_count
      @file_size = file_size
    end
  end

  attr_reader :language

  def initialize(language:)
    @language = language
  end

  def generate(cbv_flow, aggregator_report, current_agency)
    controller = Cbv::SubmitsController.new
    controller.instance_variable_set(:@cbv_flow, @cbv_flow)
    variables = {
      is_caseworker: true,
      cbv_flow: cbv_flow,
      aggregator_report: aggregator_report,
      has_consent: true,
      current_agency: current_agency
    }

    html_content = I18n.with_locale(language) do
      controller.render_to_string(
        template: "cbv/submits/show",
        formats: [ :pdf ],
        layout: "layouts/pdf",
        locals: variables,
        assigns: variables
      )
    end

    begin
      pdf_content = WickedPdf.new.pdf_from_string(html_content)
      Rails.logger.debug "PDF content generated. Size: #{pdf_content.bytesize} bytes"

      if pdf_content.nil? || pdf_content.empty?
        Rails.logger.error "PDF content is empty or nil"
        raise StandardError, "Failed to generate PDF: Content is empty or nil"
      end

      reader = PDF::Reader.new(StringIO.new(pdf_content))
      page_count = reader.page_count

      PdfGenerationResult.new(pdf_content, html_content, page_count, pdf_content.bytesize)
    rescue => e
      Rails.logger.error "Error generating PDF: #{e.message}"
      nil
    end
  end
end
