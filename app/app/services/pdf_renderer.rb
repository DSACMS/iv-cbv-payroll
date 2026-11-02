require "open3"

# All PDF entry points share tagging, browser options, and page units.
class PdfRenderer
  def self.render(html, margin: { top: 10, bottom: 10, left: 10, right: 10 }, footer: nil)
    options = { margin: margin.transform_values { |value| "#{value}mm" } }
    if footer
      options.merge!(display_header_footer: true, header_template: "<span></span>", footer_template: footer)
    end
    content = Grover.new(html, **options).to_pdf
    python = ENV.fetch("PDF_PYTHON", File.expand_path("~/.local/share/emmy/pdf-venv/bin/python"))
    output, error, status = Open3.capture3(python, "-B", Rails.root.join("lib/pdf/finalize.py").to_s,
      stdin_data: content, binmode: true)
    raise "PDF accessibility finalization failed: #{error}" unless status.success?

    output
  end
end
