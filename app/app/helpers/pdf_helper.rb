module PdfHelper
  def pdf_asset_data_uri(path)
    content, content_type = pdf_asset(path)
    "data:#{content_type};base64,#{Base64.strict_encode64(content)}"
  end

  def pdf_stylesheet
    css, = pdf_asset("application.css")
    css = css.dup.force_encoding(Encoding::UTF_8)
    css = css.gsub(/url\(["']?([^\)"']*)["']?\)/) do |original|
      path = Regexp.last_match(1)
      next original if path.blank? || path.start_with?("data:", "#")

      "url(\"#{pdf_asset_data_uri(path)}\")"
    end
    # Only trusted application assets are embedded, never user-supplied styles.
    content_tag(:style, css.html_safe)
  end

  def pdf_page_footer
    text = ERB::Util.html_escape(t("cbv.submits.show.pdf.footer.page_footer"))
    text = text.gsub("[page]", '<span class="pageNumber"></span>')
      .gsub("[topage]", '<span class="totalPages"></span>')
    %(<div style="font-size:10px;width:100%;text-align:right;margin:0 10mm">#{text}</div>)
  end

  private

  def pdf_asset(path)
    manifest = Rails.application.assets_manifest
    logical_path = path.delete_prefix("/assets/")
    logical_path = manifest.assets.key(logical_path) || logical_path
    logical_path = logical_path.sub(/-[0-9a-f]{64}(?=\.)/, "") unless manifest.assets[logical_path]
    if (digest_path = manifest.assets[logical_path])
      return [ File.binread(File.join(manifest.directory, digest_path)), Marcel::MimeType.for(name: logical_path) ]
    end
    if Rails.application.assets && (asset = Rails.application.assets.find_asset(logical_path))
      return [ asset.to_s, asset.content_type ]
    end
    # USWDS CSS references fonts and icons distributed with the npm package.
    if logical_path.start_with?("@uswds/uswds/dist/") && !logical_path.split("/").include?("..")
      return [ File.binread(Rails.root.join("node_modules", logical_path)), Marcel::MimeType.for(name: logical_path) ]
    end
    raise "PDF asset is not available: #{logical_path}"
  end
end
