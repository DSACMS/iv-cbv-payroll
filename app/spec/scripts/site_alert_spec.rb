require "spec_helper"
require "fileutils"
require "json"
require "open3"
require "tmpdir"

RSpec.describe "bin/site-alert" do # rubocop:disable RSpec/DescribeClass -- Tests a shell CLI, not a Ruby class.
  let(:script) { File.expand_path("../../../bin/site-alert", __dir__) }
  let(:current_alerts) { " other_alert, site_alert ,another_alert " }
  let(:read_failure) { "false" }
  let(:command) { "disable" }
  let(:options) { [] }
  let(:writes) { aws_calls.select { |args| args.first(2) == [ "ssm", "put-parameter" ] } }
  let(:alert_values) { writes.select { |args| args[args.index("--name") + 1].end_with?("/enabled-alerts") }.map { |args| args[args.index("--value") + 1] } }
  let(:deployments) { aws_calls.select { |args| args.first(2) == [ "ecs", "update-service" ] } }

  attr_reader :output, :status, :aws_calls

  around do |example|
    Dir.mktmpdir("site-alert-spec") do |directory|
      aws = File.join(directory, "aws")
      log = File.join(directory, "aws.jsonl")
      File.write(aws, <<~RUBY)
        #!/usr/bin/env ruby
        require "json"
        File.open(ENV.fetch("AWS_TEST_LOG"), "a") { |file| file.puts(JSON.generate(ARGV)) }
        case ARGV.first(2)
        when ["sts", "get-caller-identity"]
          puts "123456789012"
        when ["ssm", "get-parameters"]
          exit 1 if ENV.fetch("AWS_TEST_READ_FAILURE") == "true"
          puts ENV.fetch("AWS_TEST_ALERTS")
        when ["ssm", "get-parameter"]
          puts "warning"
        end
      RUBY
      FileUtils.chmod(0o755, aws)
      @output, @status = Open3.capture2e(
        {
          "PATH" => "#{directory}:#{ENV.fetch('PATH')}",
          "AWS_TEST_LOG" => log,
          "AWS_TEST_ALERTS" => current_alerts,
          "AWS_TEST_READ_FAILURE" => read_failure
        },
        "bash", script, command, "--platform", "cms", "--environment", "test", "--no-wait", *options
      )
      @aws_calls = File.exist?(log) ? File.readlines(log).map { |line| JSON.parse(line) } : []
      example.run
    end
  end

  it "removes only the selected alert and deploys" do
    expect(status).to be_success
    expect(alert_values).to eq([ "other_alert,another_alert" ])
    expect(deployments.length).to eq(1)
  end

  context "when disabling the last alert" do
    let(:current_alerts) { "site_alert" }

    it "stores a single space because SSM rejects empty strings" do
      expect(status).to be_success
      expect(alert_values).to eq([ " " ])
    end
  end

  context "when the parameter does not yet exist" do
    let(:current_alerts) { "None" }

    it "initializes a disabled value" do
      expect(status).to be_success
      expect(alert_values).to eq([ " " ])
    end
  end

  context "when the read fails" do
    let(:read_failure) { "true" }

    it "aborts without overwriting settings or deploying" do
      expect(status).not_to be_success
      expect(writes).to be_empty
      expect(deployments).to be_empty
    end
  end

  context "when enabling the generic alert" do
    let(:command) { "enable" }
    let(:options) { [ "--type", "site_alert", "--preset", "scheduled-maintenance", "--severity", "error" ] }

    it "preserves other identifiers while disabling and re-enabling the generic alert" do
      expect(status).to be_success
      expect(alert_values).to eq([ "other_alert,another_alert", "other_alert,another_alert,site_alert" ])
      expect(deployments.length).to eq(1)
    end

    it "writes the requested severity and both languages" do
      parameters = writes.to_h { |args| [ File.basename(args[args.index("--name") + 1]), args[args.index("--value") + 1] ] }
      expect(parameters).to include("site-alert-type" => "error", "site-alert-title-en" => "Scheduled Maintenance", "site-alert-title-es" => "Mantenimiento programado")
      expect(parameters.fetch("site-alert-body-en")).not_to be_empty
      expect(parameters.fetch("site-alert-body-es")).not_to be_empty
    end

    context "when no alerts are enabled" do
      let(:current_alerts) { " " }

      it "enables the generic alert without an empty identifier" do
        expect(status).to be_success
        expect(alert_values).to eq([ " ", "site_alert" ])
      end
    end
  end

  context "when showing status" do
    let(:command) { "status" }

    it "shows the enabled list and severity without changing settings" do
      expect(status).to be_success
      expect(output).to include("enabled_alerts=#{current_alerts}", "severity=warning")
      expect(writes).to be_empty
      expect(deployments).to be_empty
    end
  end

  context "with an unsupported alert type" do
    let(:options) { [ "--type", "unknown_alert" ] }

    it "rejects the type before calling AWS" do
      expect(status).not_to be_success
      expect(output).to include("unsupported alert type")
      expect(aws_calls).to be_empty
    end
  end
end
