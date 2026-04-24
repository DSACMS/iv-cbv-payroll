# frozen_string_literal: true

class DocumentUploadsComponentPreview < ApplicationPreview
  def with_remove_file
    render DocumentUploadsComponent.new(
      documents: [
        { filename: "january-paystub.pdf", remove_path: "#" },
        { filename: "february-timesheet.jpg", remove_path: "#" }
      ],
      show_remove_file: true
    )
  end

  def without_remove_file
    render DocumentUploadsComponent.new(
      documents: [
        { filename: "january-paystub.pdf" },
        { filename: "february-timesheet.jpg" }
      ]
    )
  end
end
