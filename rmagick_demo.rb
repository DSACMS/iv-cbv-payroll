# Demo C: the RMagick ALTERNATIVE — RMagick replaces vips + prawn (image -> PDF in
# ONE step), combine_pdf still does the merge + stamp.
#
# Run:  ruby rmagick_demo.rb
# Out:  rmagick_demo_out/combined_output.pdf
#
# Contrast with combine_pdf_demo.rb (vips + prawn):
#   - RMagick reads HEIC AND writes PDF directly — one gem, one step, no prawn
#   - Heavier system dep: ImageMagick (CVE history, needs hardened policy.xml),
#     higher memory (loads full-frame buffers vs vips streaming)
#   - combine_pdf is STILL required: merging PDFs through ImageMagick rasterizes
#     everything (quality + selectable-text loss), so combine_pdf does the merge
#
# System libs (ImageMagick + pkg-config, needed to COMPILE the rmagick gem) are
# auto-installed by demo_setup.rb before the gems are required.

require_relative "demo_setup"
DemoSetup.ensure(
  { check: "magick",     brew: "imagemagick", apt: "imagemagick libmagickwand-dev" },
  { check: "pkg-config", brew: "pkg-config",  apt: "pkg-config" }
)

require "bundler/inline"

gemfile do
  source "https://rubygems.org"
  gem "rmagick"      # decode HEIC + write PDF in one step (native ext vs ImageMagick)
  gem "combine_pdf"  # merge + stamp
  gem "chunky_png"   # fabricate a sample image
end

require "fileutils"
require "rmagick"
require "combine_pdf"
require "chunky_png"

OUT = File.expand_path("rmagick_demo_out", __dir__)
FileUtils.mkdir_p(OUT)

CASE_NUMBER       = "01000123456A"
CONFIRMATION_CODE = "DEMO1234"

# ---------------------------------------------------------------------------
# Fixtures: report PDF, uploaded PDF, uploaded HEIC photo
# ---------------------------------------------------------------------------
def make_sample_pdf(path, _title, pages:)
  # Plain colored pages — no text (avoids depending on a system font being
  # configured). combine_pdf adds the real stamp text later, proving stamping.
  doc = Magick::ImageList.new
  pages.times do
    doc << Magick::Image.new(612, 792) { |o| o.background_color = "white" }
  end
  doc.write(path)
end

def make_sample_heic(path)
  png_path = path.sub(/\.heic$/, "_src.png")
  img = ChunkyPNG::Image.new(400, 300, ChunkyPNG::Color::WHITE)
  (50..350).each { |x| (100..200).each { |y| img[x, y] = ChunkyPNG::Color.rgb(0, 120, 200) } }
  img.save(png_path)
  Magick::ImageList.new(png_path).write(path)   # RMagick writes HEIC
  path
end

report_path = File.join(OUT, "report.pdf")
upload_pdf  = File.join(OUT, "upload_letter.pdf")
upload_heic = File.join(OUT, "upload_photo.heic")

make_sample_pdf(report_path, "INCOME REPORT", pages: 2)
make_sample_pdf(upload_pdf,  "UPLOAD letter", pages: 3)
make_sample_heic(upload_heic)

# ---------------------------------------------------------------------------
# Step 1: RMagick reads HEIC and writes a PDF in ONE step (no vips, no prawn)
# ---------------------------------------------------------------------------
def image_to_pdf(image_path, out_path)
  img = Magick::ImageList.new(image_path)
  img.write(out_path)   # ImageMagick wraps the raster into a PDF page
  puts "rmagick: #{File.basename(image_path)} (#{img.first.columns}x#{img.first.rows}) -> #{File.basename(out_path)}"
  out_path
end

photo_pdf = image_to_pdf(upload_heic, File.join(OUT, "upload_photo.pdf"))

# ---------------------------------------------------------------------------
# Step 2: combine_pdf merges + stamps (same as the recommended stack)
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
bytes = pdf.to_pdf

puts
puts "Pipeline:       HEIC --rmagick--> PDF page --combine_pdf--> merged + stamped"
puts "Merged pages:   #{total}  (report 2 + letter 3 + converted HEIC 1)"
puts "Output PDF:     #{out_path}"
puts "In-memory size: #{bytes.bytesize} bytes"
puts "Open it:        open #{out_path}"
