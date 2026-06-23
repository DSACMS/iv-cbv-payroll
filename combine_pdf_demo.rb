# Demo A: the RECOMMENDED stack — ruby-vips (transcode) -> prawn (embed) -> combine_pdf (merge + stamp).
#
# Run:  ruby combine_pdf_demo.rb
# Out:  combine_pdf_demo_out/combined_output.pdf
#
# Full Option A pipeline, end to end:
#   1. ruby-vips transcodes an uploaded HEIC -> PNG  (libvips can't WRITE pdf; it
#      only decodes/normalizes exotic formats down to png/jpg)
#   2. prawn embeds the PNG into a one-page PDF      (prawn embeds png/jpg only)
#   3. combine_pdf merges report + uploaded PDFs + the converted image page
#   4. combine_pdf stamps case number + "page X of Y" on every page
#
# System libs (libvips w/ libheif) are auto-installed by demo_setup.rb on first run.

require_relative "demo_setup"
DemoSetup.ensure({ check: "vips", brew: "vips", apt: "libvips-tools libvips-dev" })

require "bundler/inline"

gemfile do
  source "https://rubygems.org"
  gem "ruby-vips"    # decode/transcode HEIC/TIFF/etc. -> png/jpg
  gem "prawn"        # embed png/jpg -> PDF page, + fixtures
  gem "combine_pdf"  # merge + stamp (the recommended merger)
  gem "chunky_png"   # pure-ruby: fabricate a sample image, no system deps
end

require "fileutils"
require "vips"
require "chunky_png"
require "combine_pdf"

OUT = File.expand_path("combine_pdf_demo_out", __dir__)
FileUtils.mkdir_p(OUT)

CASE_NUMBER       = "01000123456A"
CONFIRMATION_CODE = "DEMO1234"

# ---------------------------------------------------------------------------
# Fixtures: a report PDF, an uploaded PDF, and an uploaded HEIC photo
# ---------------------------------------------------------------------------
def make_sample_pdf(path, title, pages:)
  Prawn::Document.generate(path) do
    pages.times do |i|
      start_new_page if i.positive?
      text title, size: 24
      text "Sample page #{i + 1}", size: 12
    end
  end
end

def make_sample_heic(path)
  png_path = path.sub(/\.heic$/, "_src.png")
  img = ChunkyPNG::Image.new(400, 300, ChunkyPNG::Color::WHITE)
  (50..350).each { |x| (100..200).each { |y| img[x, y] = ChunkyPNG::Color.rgb(0, 120, 200) } }
  img.save(png_path)
  # write a real HEIC (iPhone's default upload format) so we exercise vips HEIC decode
  Vips::Image.new_from_file(png_path).write_to_file(path)
  path
end

report_path  = File.join(OUT, "report.pdf")
upload_pdf   = File.join(OUT, "upload_letter.pdf")
upload_heic  = File.join(OUT, "upload_photo.heic")

make_sample_pdf(report_path, "INCOME REPORT",      pages: 2)
make_sample_pdf(upload_pdf,  "UPLOAD: letter.pdf", pages: 3)
make_sample_heic(upload_heic)

# ---------------------------------------------------------------------------
# Step 1: ruby-vips transcodes HEIC -> PNG (prawn can't read HEIC)
# ---------------------------------------------------------------------------
def transcode_to_png(src, out_path)
  image = Vips::Image.new_from_file(src)
  image.write_to_file(out_path)   # picks PNG saver from the .png extension
  puts "vips: transcoded #{File.basename(src)} (#{image.width}x#{image.height}) -> #{File.basename(out_path)}"
  out_path
end

photo_png = transcode_to_png(upload_heic, File.join(OUT, "upload_photo.png"))

# ---------------------------------------------------------------------------
# Step 2: prawn embeds the PNG into a one-page PDF (image -> PDF == embedding)
# ---------------------------------------------------------------------------
def image_to_pdf(image_path, out_path, label:)
  Prawn::Document.generate(out_path, margin: 36) do
    image image_path, fit: [bounds.width, bounds.height - 30], position: :center
    draw_text label, at: [bounds.left, bounds.bottom - 12], size: 8
  end
  out_path
end

photo_pdf = image_to_pdf(photo_png, File.join(OUT, "upload_photo.pdf"),
                         label: "Document (converted from HEIC) • Case #{CASE_NUMBER}")

# ---------------------------------------------------------------------------
# Step 3 + 4: merge report + uploaded PDFs + converted image, then stamp
# ---------------------------------------------------------------------------
pdf = CombinePDF.load(report_path)
[ upload_pdf, photo_pdf ].each { |path| pdf << CombinePDF.load(path) }

total = pdf.pages.count
pdf.pages.each_with_index do |page, i|
  page.textbox(
    "Case #{CASE_NUMBER}  -  Conf #{CONFIRMATION_CODE}  -  page #{i + 1} of #{total}",
    height: 18, width: page.mediabox[2],
    x: 12, y: 6, font_size: 8, text_align: :left, text_valign: :bottom,
    font_color: [ 0, 0, 0 ]
  )
end

out_path = File.join(OUT, "combined_output.pdf")
pdf.save(out_path)
bytes = pdf.to_pdf   # what the transmitter would send

puts
puts "Pipeline:       HEIC --vips--> PNG --prawn--> PDF page --combine_pdf--> merged + stamped"
puts "Merged pages:   #{total}  (report 2 + letter 3 + converted HEIC 1)"
puts "Output PDF:     #{out_path}"
puts "In-memory size: #{bytes.bytesize} bytes"
puts "Open it:        open #{out_path}"
