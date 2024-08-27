class PdfService
  def generate_pdf(template, variables)
    html = ApplicationController.render(
      template: template,
      layout: "pdf",
      locals: variables[:locals]
    )

    pdf = WickedPdf.new.pdf_from_string(html)

    file_path = Rails.root.join("tmp", "#{SecureRandom.hex}.pdf")
    File.open(file_path, "wb") do |file|
      file << pdf
    end

    file_path.to_s
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
