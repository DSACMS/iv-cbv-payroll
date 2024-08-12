require "fileutils"

class PdfService
  def initialize(case_id)
    @case_id = case_id
  end

  def generate_pdf(template, variables)
    pdf_content = WickedPdf.new.pdf_from_string(
      render_to_string(template: template, formats: [ :pdf ], variables: variables)
    )

    file_name = "#{@case_id}_#{Date.today.strftime('%Y%m%d')}.pdf"
    file_path = Rails.root.join("tmp", file_name)

    FileUtils.mkdir_p(File.dirname(file_path))
    File.open(file_path, "wb") { |file| file.write(pdf_content) }

    file_path
  end

  private

  def render_to_string(template:, formats:, variables:)
    ApplicationController.renderer.render(
      template: template,
      formats: formats,
      layout: false,
      assigns: variables
    )
  end
end
