# WickedPDF Global Configuration
#
# Use this to set up shared configuration options for your entire application.
# Any of the configuration options shown here can also be applied to single
# models by passing arguments to the `render :pdf` call.
#
# To learn more, check out the README:
#
# https://github.com/mileszs/wicked_pdf/blob/master/README.md

WickedPdf.configure do |config|

  # create the tmp directory
  wicked_pdf_tempfile_dir = Rails.root.join("tmp", "wicked_pdf_temp")
  Rails.application.config.wicked_pdf_tempfile_dir = wicked_pdf_tempfile_dir.to_s
  Dir.mkdir(wicked_pdf_tempfile_dir) unless Dir.exist?(wicked_pdf_tempfile_dir)

  config[:temp_path] = wicked_pdf_tempfile_dir

  # Path to the wkhtmltopdf executable: This usually isn't needed if using
  # one of the wkhtmltopdf-binary family of gems.
  config.exe_path = '/usr/bin/wkhtmltopdf'
  #   or
  # config.exe_path = Gem.bin_path('wkhtmltopdf-binary', 'wkhtmltopdf')

  # Needed for wkhtmltopdf 0.12.6+ to use many wicked_pdf_temp asset helpers
  # config.enable_local_file_access = true

  # Layout file to be used for all PDFs
  # (but can be overridden in `render :pdf` calls)
  # config.layout = 'pdf.html',

  # Using wkhtmltopdf without an X server can be achieved by enabling the
  # 'use_xvfb' flag. This will wrap all wkhtmltopdf commands around the
  # 'xvfb-run' command, in order to simulate an X server.
  #
  # config.use_xvfb = true,
end
