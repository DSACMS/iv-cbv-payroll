# Export synthetic PDFs from integration specs for the veraPDF CI gate.
# Never enable this in the application: reports may contain beneficiary data.
if ENV["PDF_ACCESSIBILITY_OUTPUT_DIR"].present?
  RSpec.configure do |config|
    config.before(:suite) do
      PdfRenderer.singleton_class.prepend(Module.new do
        def render(html, **options)
          content = super
          # Mocked renderer output is not a generated PDF to validate.
          return content if RSpec.current_example&.metadata&.fetch(:skip_pdf_accessibility_export, false)

          directory = ENV.fetch("PDF_ACCESSIBILITY_OUTPUT_DIR")
          FileUtils.mkdir_p(directory)
          File.binwrite(File.join(directory, "#{Digest::SHA256.hexdigest(content)}.pdf"), content)
          content
        end
      end)
    end
  end
end
