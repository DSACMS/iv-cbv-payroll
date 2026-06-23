# Demo B: the ALTERNATIVE stack — ruby-vips (transcode) + prawn + prawn-templates.
# prawn-templates does the merge (instead of combine_pdf); prawn embeds + stamps.
#
# Run:  ruby prawn_demo.rb
# Out:  prawn_demo_out/combined_output.pdf
#
# Compare against combine_pdf_demo.rb. Same end result; differences to judge:
#   - License: prawn-templates is GPL-2/3/Ruby (Ruby path CC0-compatible) vs combine_pdf MIT
#   - Merging existing PDFs: prawn-templates re-parses each source page via `template:`
#     — more fragile on complex/odd PDFs than combine_pdf's merger
#   - Still needs ruby-vips for HEIC: prawn embeds png/jpg only, can't read HEIC
#
# System libs (libvips w/ libheif) are auto-installed by demo_setup.rb on first run.

require_relative "demo_setup"
DemoSetup.ensure({ check: "vips", brew: "vips", apt: "libvips-tools libvips-dev" })

require "bundler/inline"

gemfile do
  source "https://rubygems.org"
  gem "ruby-vips"
  gem "prawn"
  gem "prawn-templates"
  gem "chunky_png"
end

require "fileutils"
require "vips"
require "prawn"
require "prawn/templates"
require "chunky_png"

OUT = File.expand_path("prawn_demo_out", __dir__)
FileUtils.mkdir_p(OUT)

CASE_NUMBER       = "01000123456A"
CONFIRMATION_CODE = "DEMO1234"

# ---------------------------------------------------------------------------
# Fixtures
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
  Vips::Image.new_from_file(png_path).write_to_file(path)
  path
end

report_path = File.join(OUT, "report.pdf")
upload_pdf  = File.join(OUT, "upload_letter.pdf")
upload_heic = File.join(OUT, "upload_photo.heic")

make_sample_pdf(report_path, "INCOME REPORT",      pages: 2)
make_sample_pdf(upload_pdf,  "UPLOAD: letter.pdf", pages: 3)
make_sample_heic(upload_heic)

# HEIC -> PNG (prawn can't read HEIC either) — same vips step as the recommended stack
photo_png = File.join(OUT, "upload_photo.png")
Vips::Image.new_from_file(upload_heic).write_to_file(photo_png)
puts "vips: transcoded #{File.basename(upload_heic)} -> #{File.basename(photo_png)}"

# ---------------------------------------------------------------------------
# Build: start from the report (all pages via template), append image page +
# uploaded PDF pages (via template), then stamp every page. All in prawn.
# ---------------------------------------------------------------------------
pdf = Prawn::Document.new(template: report_path)

# Append the converted image as its own page (prawn embeds png natively)
pdf.start_new_page
pdf.image photo_png, fit: [pdf.bounds.width, pdf.bounds.height - 30], position: :center

# Append every page of an uploaded PDF via prawn-templates
upload_pages = Prawn::Document.new(template: upload_pdf).page_count
(1..upload_pages).each do |n|
  pdf.start_new_page(template: upload_pdf, template_page: n)
end

# Stamp case number + page X of Y on every page
total = pdf.page_count
(1..total).each do |i|
  pdf.go_to_page(i)
  pdf.draw_text "Case #{CASE_NUMBER}  -  Conf #{CONFIRMATION_CODE}  -  page #{i} of #{total}",
                at: [pdf.bounds.left, pdf.bounds.bottom - 18], size: 8
end

out_path = File.join(OUT, "combined_output.pdf")
pdf.render_file(out_path)
bytes = pdf.render

puts "Pipeline:       HEIC --vips--> PNG --prawn(template merge + embed + stamp)--> PDF"
puts "Merged pages:   #{total}  (report 2 + converted HEIC 1 + letter 3)"
puts "Output PDF:     #{out_path}"
puts "In-memory size: #{bytes.bytesize} bytes"
puts "Open it:        open #{out_path}"
