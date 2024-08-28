class PdfService
  def self.generate(template:, variables: {})
    @html_content = ApplicationController.renderer.render(
      template: template,
      formats: [ :pdf ],
      layout: "layouts/pdf",
      locals: variables,
      assigns: variables
    )

    Rails.logger.debug "HTML content generated: #{@html_content.truncate(100)}"

    begin
      @pdf_content = WickedPdf.new.pdf_from_string(@html_content)
      Rails.logger.debug "PDF content generated. Size: #{@pdf_content.bytesize} bytes"

      if @pdf_content.nil? || @pdf_content.empty?
        Rails.logger.error "PDF content is empty or nil"
        return nil
      end

      @file_path = "#{Rails.root}/tmp/#{SecureRandom.uuid}.pdf"
      File.binwrite(@file_path, @pdf_content)

      @file_path
    rescue => e
      Rails.logger.error "Error generating PDF: #{e.message}"
      nil
    end
  end

  def self.get_html
    @html_content
  end

  def self.get_pdf
    @pdf_content
  end
end
