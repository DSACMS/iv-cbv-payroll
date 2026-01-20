# frozen_string_literal: true

require "rails_helper"

TEST_LABEL = "text"

SUCCEEDED_ICON_CLASSES = [
  "text-white",
  "bg-primary",
  "border-primary"
]

IN_PROGRESS_ICON_CLASSES = [
  "rotate",
  "border-base-light"
]

FAILED_ICON_CLASSES = [
  "bg-base-darker",
  "text-white",
  "border-base-darker"
]

RSpec.shared_examples "common" do
  before do
    render_inline(subject.with_content(TEST_LABEL))
  end

  it "renders a synchronization indicator element" do
    expect(page).to have_css(".synchronizations-indicator")
  end

  it "renders an icon with proper accessibility attributes" do
    icon = page.find(:css, ".synchronizations-indicator svg")

    expect(icon["aria-hidden"]).to eq("true")
    expect(icon["focusable"]).to eq("false")
    expect(icon["role"]).to eq("img")
  end

  it "renders an icon with proper styling classes" do
    icon = page.find(:css, ".synchronizations-indicator svg")
    icon_classes = icon["class"].split

    expect(icon_classes).to include("synchronizations-indicator__spinner",
                                    "usa-icon",
                                    "usa-icon--size-5")
  end

  it "renders a label with proper styling classes" do
    label = page.find(:css, ".synchronizations-indicator span")
    label_classes = label["class"].split

    expect(label_classes).to include("margin-top-05")
    expect(label).to have_content(TEST_LABEL)
  end
end


RSpec.describe SynchronizationIndicatorComponent, type: :component do
  context "in progress" do
    subject { described_class.new status: :in_progress }

    it_behaves_like "common"

    it "renders the in progress icon" do
      icon = page.find(:css, ".synchronizations-indicator svg")
      icon_classes = icon["class"].split

      expect(icon.find(:css, "use")["xlink:href"]).to end_with("#autorenew")
      expect(icon_classes).to include(*IN_PROGRESS_ICON_CLASSES)
      expect(icon_classes).not_to include(*SUCCEEDED_ICON_CLASSES)
      expect(icon_classes).not_to include(*FAILED_ICON_CLASSES)
    end

    it "renders a label with thin text" do
      label = page.find(:css, ".synchronizations-indicator span")
      label_classes = label["class"].split

      expect(label_classes).to include("text-thin")
    end
  end

  context "succeeded" do
    subject { described_class.new status: :succeeded }

    it_behaves_like "common"

    it "renders the check icon" do
      icon = page.find(:css, ".synchronizations-indicator svg")
      icon_classes = icon["class"].split

      expect(icon.find(:css, "use")["xlink:href"]).to end_with("#check")
      expect(icon_classes).not_to include(*IN_PROGRESS_ICON_CLASSES)
      expect(icon_classes).to include(*SUCCEEDED_ICON_CLASSES)
      expect(icon_classes).not_to include(*(FAILED_ICON_CLASSES - SUCCEEDED_ICON_CLASSES))
    end

    it "renders a label with bold, primary text" do
      label = page.find(:css, ".synchronizations-indicator span")
      label_classes = label["class"].split

      expect(label_classes).to include("text-bold", "text-primary")
    end
  end

  context "failed" do
    subject { described_class.new status: :failed }

    it_behaves_like "common"

    it "renders the check icon" do
      icon = page.find(:css, ".synchronizations-indicator svg")
      icon_classes = icon["class"].split

      expect(icon.find(:css, "use")["xlink:href"]).to end_with("#priority_high")
      expect(icon_classes).not_to include(*IN_PROGRESS_ICON_CLASSES)
      expect(icon_classes).not_to include(*(SUCCEEDED_ICON_CLASSES - FAILED_ICON_CLASSES))
      expect(icon_classes).to include(*FAILED_ICON_CLASSES)
    end

    it "renders a label with bold non-primary text" do
      label = page.find(:css, ".synchronizations-indicator span")
      label_classes = label["class"].split

      expect(label_classes).to include("text-bold")
      expect(label_classes).not_to include("text-primary")
    end
  end
end
