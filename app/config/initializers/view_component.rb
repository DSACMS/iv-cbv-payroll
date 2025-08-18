if defined?(ViewComponent)
  ViewComponent::Base.config.tap do |config|
    config.preview_paths ||= []
    config.preview_paths << Rails.root.join("spec", "components", "previews")
    config.default_preview_layout = "component_preview"
  end
end
