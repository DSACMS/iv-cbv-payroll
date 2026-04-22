# frozen_string_literal: true

class DocumentUploadsComponent < ViewComponent::Base
  def initialize(documents:, show_remove_file: false, heading_level: 2)
    @documents = documents
    @show_remove_file = show_remove_file
    @heading_level = heading_level
  end

  private

  attr_reader :documents, :heading_level

  def heading_text
    I18n.t("components.document_uploads.heading", document_count: documents.count)
  end

  def show_remove_file?
    @show_remove_file
  end

  def filename_for(document)
    document.fetch(:filename)
  end

  def remove_path_for(document)
    document[:remove_path]
  end

  def icon_path
    helpers.uswds_sprite_icon_href("file_present")
  end
end
