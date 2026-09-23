# In production (config.assets.compile = false), wicked_pdf can only embed
# assets that were precompiled. In test it finds anything on the asset load
# path, including node_modules, so enforce the production behavior here.
module WickedPdfPrecompiledAssetGuard
  def wicked_pdf_asset_base64(path)
    unless Rails.application.asset_precompiled?(path)
      raise "Asset '#{path}' is not precompiled and will be missing in production. " \
        "Add it to app/assets/config/manifest.js."
    end

    super
  end
end

WickedPdf::WickedPdfHelper::Assets.prepend(WickedPdfPrecompiledAssetGuard)
