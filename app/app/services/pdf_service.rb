class PdfService
  PDFOutput = Struct.new(:path, :html, :content, :file_name, :file_size, :page_count)

  def self.generate(template:, variables: {}, file_name: nil)
    html_content = ApplicationController.renderer.render_to_string(
      template: template,
      formats: [ :pdf ],
      layout: "layouts/pdf",
      locals: variables,
      assigns: variables
    )

    begin
      pdf_content = WickedPdf.new.pdf_from_string(html_content)
      Rails.logger.debug "PDF content generated. Size: #{pdf_content.bytesize} bytes"

      if pdf_content.nil? || pdf_content.empty?
        Rails.logger.error "PDF content is empty or nil"
        raise StandardError, "Failed to generate PDF: Content is empty or nil"
      end

      if file_name.nil?
        file_name = "#{template.parameterize}-#{SecureRandom.uuid}"
      end
      file_name = "#{file_name.sub(".pdf", "")}" # remove the .pdf extension if passed
      file_path = "#{Rails.root}/tmp/#{file_name}.pdf"

      File.binwrite(file_path, pdf_content)

      reader = PDF::Reader.new(file_path)
      page_count = reader.page_count
      file_size = File.size(file_path)
      PDFOutput.new(file_path, html_content, pdf_content, file_name, file_size, page_count)
    rescue => e
      Rails.logger.error "Error generating PDF: #{e.message}"
      nil
    end
  end
end
