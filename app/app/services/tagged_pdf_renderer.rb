# class TaggedPdfRenderer
#   def self.render(html, margin: {}, footer: nil)
#     options = {
#       tagged: true,
#       outline: true,
#       viewport: { width: 1280, height: 1024 }
#     }
#     options[:executable_path] = ENV["CHROME_BIN"] if ENV["CHROME_BIN"].present?
#     options[:launch_args] = [ "--no-sandbox" ] if Process.uid.zero?
#     options[:margin] = margin.transform_values { |value| value.is_a?(Numeric) ? "#{value}mm" : value } if margin.present?
#     if footer
#       options[:display_header_footer] = true
#       options[:footer_template] = <<~HTML
#         <div style="width: 100%; padding: 0 8mm; font-size: #{footer.fetch(:font_size, 10)}px; text-align: right;">
#           #{ERB::Util.html_escape(footer.fetch(:text))} | Page <span class="pageNumber"></span> of <span class="totalPages"></span>
#         </div>
#       HTML
#     end

#     Grover.new(html, **options).to_pdf
#   end
# end

require "hexapdf"
require "stringio"

class TaggedPdfRenderer
  PDF_AUTHOR = "Emmy application"
  PDF_SUBJECT = "Emmy Community Engagement and/or Income submission"

  def self.render(html, margin: {}, footer: nil)
    html = remove_responsive_table_labels(html)

    options = {
      tagged: true,
      outline: true,
      emulate_media: "print",
      viewport: { width: 1280, height: 1024 }
    }

    options[:launch_args] = [ "--export-tagged-pdf" ]

    options[:launch_args] << "--no-sandbox" if Process.uid.zero?

    options[:executable_path] = ENV["CHROME_BIN"] if ENV["CHROME_BIN"].present?
    options[:margin] = margin.transform_values { |value| value.is_a?(Numeric) ? "#{value}mm" : value } if margin.present?

    if footer
      options[:display_header_footer] = true
      options[:footer_template] = <<~HTML
        <div style="width: 100%; padding: 0 8mm; font-size: #{footer.fetch(:font_size, 10)}px; text-align: right;">
          #{ERB::Util.html_escape(footer.fetch(:text))} | Page <span class="pageNumber"></span> of <span class="totalPages"></span>
        </div>
      HTML
    end

    pdf = add_document_metadata(Grover.new(html, **options).to_pdf)
    normalize_chromium_text_tags(pdf)
  end

  def self.remove_responsive_table_labels(html)
    document = Nokogiri::HTML.parse(html)

    document.css("table [data-label]").each do |cell|
      cell.remove_attribute("data-label")
    end

    document.to_html
  end
  private_class_method :remove_responsive_table_labels

  def self.add_document_metadata(pdf)
    document = HexaPDF::Document.new(io: StringIO.new(pdf))
    document.trailer.info[:Author] = PDF_AUTHOR
    document.trailer.info[:Subject] = PDF_SUBJECT

    output = StringIO.new
    document.write(output)
    output.string
  end
  private_class_method :add_document_metadata

  def self.normalize_chromium_text_tags(pdf)
    # Chromium emits static text as /NonStruct. Some PDF viewers expose those
    # marked-content wrappers as "mc ref graphic". /Span is the equivalent
    # standard inline text tag and keeps the existing byte offsets intact.
    pdf.gsub("/S /NonStruct", "/S /Span     ")
  end
  private_class_method :normalize_chromium_text_tags
end
