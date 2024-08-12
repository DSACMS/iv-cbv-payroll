class PdfService
  def generate_pdf(template, variables)
    pdf_content = WickedPdf.new.pdf_from_string(
      render_to_string(template: template, variables: variables)
    )

    file_name = "#{SecureRandom.uuid}.pdf"
    file_path = Rails.root.join("tmp", file_name)

    FileUtils.mkdir_p(File.dirname(file_path))
    File.open(file_path, "wb") { |file| file.write(pdf_content) }

    file_path
  end

  private

  def render_to_string(template:, variables:)
    ApplicationController.renderer.render(
      template: template,
      formats: [ :pdf ],
      layout: false,
      assigns: variables
    )
  end
end
