require "rails_helper"
require "tmpdir"
require "open3"

# This spec exercises an executable script rather than a class.
RSpec.describe "bin/check-pdf-accessibility" do # rubocop:disable RSpec/DescribeClass
  let(:specification) { "ISO 14289-1:2014" }
  let(:rules) { [] }
  let(:compliant) { rules.empty? ? "true" : "false" }
  let(:job_status) { "normal" }
  let(:command_status) { instance_double(Process::Status, success?: true) }
  let(:report) do
    rule_xml = rules.map do |clause, number|
      %(<rule specification="#{specification}" clause="#{clause}" testNumber="#{number}" status="failed" failedChecks="2"><description>Content | &lt;tag&gt; is untagged</description></rule>)
    end.join
    <<~XML
      <report><jobs><job><item><name>/synthetic/report.pdf</name></item>
        <validationReport jobEndStatus="#{job_status}" isCompliant="#{compliant}">
          <details failedRules="#{rules.length}">#{rule_xml}</details>
        </validationReport>
      </job></jobs></report>
    XML
  end

  around do |example|
    Dir.mktmpdir("pdf-validation-spec-") do |directory|
      ClimateControl.modify("PDF_ACCESSIBILITY_REPORT_DIR" => directory) { example.run }
    end
  end

  before do
    stub_const("ARGV", [ "/synthetic/report.pdf" ])
    allow(Open3).to receive(:capture3).and_return([ report, "", command_status ])
  end

  def run_check
    load Rails.root.join("bin/check-pdf-accessibility")
  end

  def summary
    File.read(File.join(ENV.fetch("PDF_ACCESSIBILITY_REPORT_DIR"), "summary.md"))
  end

  it "writes a readable summary for compliant PDFs" do
    run_check
    expect(summary).to include("report.pdf", "No failed rules", "Check passed")
  end

  it "accepts compliant PDFs" do
    expect { run_check }.to output(/1 PDFs checked: 0 expected rule failures, no unexpected failures/).to_stdout
  end

  context "with all four accepted Chromium violations" do
    let(:rules) { [ [ "7.1", "3" ], [ "7.1", "8" ], [ "7.1", "5" ], [ "7.2", "20" ] ] }

    it "reports expected failures without claiming compliance" do
      expect { run_check }.to output(/4 expected rule failures.*This does not establish PDF\/UA compliance/m).to_stdout
    end

    it "lists accepted rules, counts, and escaped descriptions" do
      run_check
      expect(summary).to include("ISO 14289-1:2014 / 7.1 / 3", "| 2 | Accepted Chromium limitation")
      expect(summary).to include("Content &#124; &lt;tag&gt; is untagged", "does not establish PDF/UA compliance")
    end

    it "preserves the original validation evidence" do
      run_check

      expect(File.read(File.join(ENV.fetch("PDF_ACCESSIBILITY_REPORT_DIR"), "verapdf.xml"))).to eq(report)
    end

    context "with a different specification" do
      let(:specification) { "another standard" }

      it "rejects rules from an unrecognized specification" do
        expect { run_check }.to raise_error(SystemExit)
      end
    end
  end

  context "with an unexpected violation alongside expected failures" do
    let(:rules) { [ [ "7.1", "8" ], [ "7.1", "99" ] ] }

    it "fails the check and preserves both failure classifications" do
      expect { run_check }.to raise_error(SystemExit) { |error| expect(error.status).to eq(1) }
      expect(summary).to include("Accepted Chromium limitation", "Unexpected failure", "1 unexpected rule failures")
    end
  end

  context "when veraPDF exits unsuccessfully" do
    let(:command_status) { instance_double(Process::Status, success?: false) }

    it "fails even with a compliant report" do
      expect { run_check }.to raise_error(SystemExit)
      expect(summary).to include("veraPDF exited unsuccessfully")
    end
  end

  context "with missing validation results" do
    let(:report) { "<report />" }

    it "fails the check" do
      expect { run_check }.to raise_error(SystemExit)
      expect(summary).to include("Missing validation results: expected 1, received 0")
    end
  end

  context "with multiple PDFs returned in a different order" do
    let(:rules) { [ [ "7.1", "3" ] ] }
    let(:report) do
      first_job = super().match(%r{<job>.*</job>}m)[0]
      second_job = first_job.sub("report.pdf", "second.pdf")
      "<report><jobs>#{second_job}#{first_job}</jobs></report>"
    end

    before { stub_const("ARGV", [ "/synthetic/report.pdf", "/synthetic/second.pdf" ]) }

    it "uses each result's filename rather than the input order" do
      run_check
      expect(summary).to match(/second.pdf.*report.pdf/m)
      expect(summary).to include("2 PDFs checked", "2 expected rule failures")
    end
  end

  context "with no input PDFs" do
    before { stub_const("ARGV", []) }

    it "writes an explanation and fails without invoking veraPDF" do
      expect { run_check }.to raise_error(SystemExit)
      expect(summary).to include("No PDFs found")
      expect(Open3).not_to have_received(:capture3)
    end
  end

  context "when veraPDF is not installed" do
    before { allow(Open3).to receive(:capture3).and_raise(Errno::ENOENT) }

    it "writes an installation error and fails" do
      expect { run_check }.to raise_error(SystemExit)
      expect(summary).to include("Could not run veraPDF")
    end
  end

  context "with an abnormal validation result" do
    let(:job_status) { "failed" }

    it "fails the check" do
      expect { run_check }.to raise_error(SystemExit)
    end
  end

  context "with unexplained noncompliance" do
    let(:compliant) { "false" }

    it "rejects a noncompliant result without failed rules" do
      expect { run_check }.to raise_error(SystemExit)
    end
  end

  context "with malformed XML" do
    let(:report) { "<report>" }

    it "rejects the report" do
      expect { run_check }.to raise_error(SystemExit)
      expect(summary).to include("malformed XML")
    end
  end
end
