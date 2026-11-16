# All PDF entry points share tagging, browser options, and page units.
class PdfRenderer
  def self.render(html, margin: { top: 10, bottom: 10, left: 10, right: 10 }, footer: nil)
    options = { margin: margin.transform_values { |value| "#{value}mm" } }
    if footer
      options.merge!(display_header_footer: true, header_template: "<span></span>", footer_template: footer)
    end
    Grover.new(html, **options).to_pdf
  end
end
