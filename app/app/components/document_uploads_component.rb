# frozen_string_literal: true

class DocumentUploadsComponent < ViewComponent::Base
  def initialize(documents:, show_remove_file: false, heading_level: 2, edit_path: nil, edit_label: nil, full_width: false, previously_uploaded: false)
    @documents = documents
    @show_remove_file = show_remove_file
    @heading_level = heading_level
    @edit_path = edit_path
    @edit_label = edit_label
    @full_width = full_width
    @previously_uploaded = previously_uploaded
  end

  private

  attr_reader :documents, :heading_level, :edit_path

  def section_class
    classes = [ "document-uploads" ]
    classes << "document-uploads--full-width" if @full_width
    classes.join(" ")
  end

  def heading_text
    # i18n-tasks-use t('activities.document_uploads.heading')
    # i18n-tasks-use t('activities.document_uploads.heading_previous')
    key = @previously_uploaded ? "activities.document_uploads.heading_previous" : "activities.document_uploads.heading"
    I18n.t(key, document_count: documents.count)
  end

  def show_remove_file?
    @show_remove_file
  end

  def edit_label
    @edit_label || I18n.t("activities.hub.edit")
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
