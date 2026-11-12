require "hexapdf"

# Repairs Chromium output for our report templates. Untagged vector drawings in
# these templates are backgrounds, borders, and decorative icons. Meaningful
# graphics must have an accessible HTML description so Chromium tags them.
class PdfAccessibilityFinalizer
  PATH_PAINT_OPERATORS = %i[S s f F f* B B* b b* sh].freeze
  TEXT_OPERATORS = [ :Tj, :TJ, :"'", :'"' ].freeze

  class ContentSerializer < HexaPDF::Serializer
    # Chromium uses more than six decimal places for some transforms. Avoid
    # rounding those transforms enough to change text or border rasterization.
    def serialize_float(value)
      return super unless value.finite?

      format("%.12f", value).sub(/0+\z/, "").sub(/\.\z/, ".0")
    end
  end

  class TextDecoder < HexaPDF::Content::Processor
    public :decode_text

    # Forms are inspected separately; do not mix their text with page text.
    def paint_xobject(_name)
    end
  end

  def self.call(content, footer: nil)
    new.call(content, footer: footer)
  end

  def call(content, footer: nil)
    document = HexaPDF::Document.new(io: StringIO.new(content))
    unless document.catalog[:StructTreeRoot] && document.catalog[:MarkInfo]&.[](:Marked)
      raise ArgumentError, "PDF accessibility finalization requires tagged Chromium output"
    end
    normalize_structure(document)
    document.pages.each_with_index do |page, index|
      footer_text = footer_text_for(footer, index + 1, document.pages.count) if footer
      page.contents = mark_decorations(page.contents, page.resources, footer_text)
      page[:Tabs] = :S
    end
    document.catalog[:ViewerPreferences] ||= {}
    document.catalog[:ViewerPreferences][:DisplayDocTitle] = true
    document.metadata.register_namespace("pdfuaid", "http://www.aiim.org/pdfua/ns/id/")
    document.metadata.register_property_type("pdfuaid", "part", "Integer")
    document.metadata.property("pdfuaid", "part", 1)
    output = StringIO.new
    document.write(output)
    output.string
  end

  private

  def normalize_structure(document)
    root = document.catalog[:StructTreeRoot]
    root[:RoleMap] ||= {}
    root[:RoleMap][:Em] ||= :Span
    root[:RoleMap][:Strong] ||= :Span

    document.each.to_a.each do |node|
      next unless node.is_a?(HexaPDF::Dictionary) && node[:S] == :LI

      children = node[:K].is_a?(HexaPDF::PDFArray) ? node[:K].to_a : [ node[:K] ]
      # Keep direct MCID/MCR ownership unchanged. Chromium's affected lists
      # contain child structure elements; moving those preserves ParentTree.
      next unless children.all? { |child| child.is_a?(HexaPDF::Dictionary) && child[:Type] == :StructElem }

      node[:K] = children.chunk { |child| !%i[Lbl LBody].include?(child[:S]) }.flat_map do |needs_body, group|
        next group unless needs_body

        body = document.add({ Type: :StructElem, S: :LBody, P: node, K: group })
        group.each { |child| child[:P] = body }
        [ body ]
      end
    end
  end

  def mark_decorations(contents, resources, footer_text)
    operations = []
    scopes = []
    serializer = ContentSerializer.new
    decoder = TextDecoder.new(resources)
    HexaPDF::Content::Parser.parse(contents) do |operator, operands|
      decoder.process(operator, operands)
      case operator
      when :BMC
        scopes.push(operands.first == :Artifact)
      when :BDC
        properties = operands[1]
        properties = resources[:Properties]&.[](properties) if properties.is_a?(Symbol)
        scopes.push(operands.first == :Artifact || properties&.key?(:MCID))
      when :EMC
        scopes.pop
      end
      decorative = !scopes.any? && (
        PATH_PAINT_OPERATORS.include?(operator) ||
        (operator == :Do && decorative_form?(resources[:XObject]&.[](operands.first)))
      )
      text = decoder.decode_text(operands.last) if !scopes.any? && TEXT_OPERATORS.include?(operator)
      serialized = HexaPDF::Content::Operator::DEFAULT_OPERATORS[operator].serialize(serializer, *operands)
      operations << [ serialized, decorative, text ]
    end
    untagged_text = operations.filter_map(&:last).join
    footer_matches = footer_text.present? && normalized_text(untagged_text) == normalized_text(footer_text)
    operations.map do |serialized, decorative, text|
      if text && footer_matches
        "/Artifact <</Type /Pagination /Subtype /Footer>> BDC\n#{serialized}EMC\n"
      elsif decorative || (text && text.match?(/\A\s*\z/))
        "/Artifact BMC\n#{serialized}EMC\n"
      else
        serialized
      end
    end.join.b
  end

  def footer_text_for(footer, page_number, page_count)
    fragment = Nokogiri::HTML.fragment(footer)
    fragment.css(".pageNumber").each { |node| node.content = page_number.to_s }
    fragment.css(".totalPages").each { |node| node.content = page_count.to_s }
    fragment.text
  end

  def normalized_text(text)
    text.unicode_normalize(:nfkc).gsub(/\s+/, "")
  end

  # Do not hide images, text, or tagged content inside a Form XObject. Leave
  # unfamiliar content unmodified so accessibility validation still catches it.
  def decorative_form?(form, visited = [])
    return false unless form && form[:Subtype] == :Form
    return false if form.key?(:StructParents) || visited.include?(form)

    decorative = true
    HexaPDF::Content::Parser.parse(form.stream) do |operator, operands|
      decorative = false if TEXT_OPERATORS.include?(operator) || operator == :BDC || operator == :BI
      if operator == :Do
        child = form[:Resources]&.[](:XObject)&.[](operands.first)
        decorative &&= decorative_form?(child, visited + [ form ])
      end
    end
    decorative
  end
end
