require "pdf-reader"

class PdfService
  include ApplicationHelper
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

  def self.generate(current_site = nil, template:, variables: {})
    resolved_site = current_site || ApplicationHelper.current_site
    new(resolved_site).generate(template: template, variables: variables)
  end

  def initialize(site)
    @site = site
  end

  def generate(template:, variables: {})
    html_content = ApplicationController.renderer.render_to_string(
      template: template,
      formats: [ :pdf ],
      layout: "layouts/pdf",
      # There's some dependency injection going on here. passing in
      # the higher order method `current_site` of the ApplicationHelper
      # so that it's available in the views.
      locals: variables.merge(current_site: current_site),
      assigns: variables.merge(current_site: current_site)
    )

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

  private

  def current_site
    @site
  end
end
