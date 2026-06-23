require "rails_helper"

RSpec.describe InternalEnvironment do
  describe ".internal?" do
    subject(:internal_environment) do
      described_class.internal?(domain_name: domain_name, rails_env: rails_env)
    end

    let(:domain_name) { "example.com" }
    let(:rails_env) { ActiveSupport::StringInquirer.new("production") }

    context "when Rails env is development" do
      let(:rails_env) { ActiveSupport::StringInquirer.new("development") }

      it { is_expected.to be true }
    end

    context "when Rails env is test" do
      let(:rails_env) { ActiveSupport::StringInquirer.new("test") }

      it { is_expected.to be true }
    end

    context "when the domain is UAT" do
      let(:domain_name) { "uat.emmy.cms.gov" }

      it { is_expected.to be true }
    end

    context "when the domain is dev" do
      let(:domain_name) { "verify-demo.navapbc.cloud" }

      it { is_expected.to be true }
    end

    context "when the domain is demo" do
      let(:domain_name) { "demo.reportmyincome.org" }

      it { is_expected.to be true }
    end

    context "when the domain is CMS dev" do
      let(:domain_name) { "dev.emmy.cms.gov" }

      it { is_expected.to be true }
    end

    context "when the domain is CMS demo" do
      let(:domain_name) { "demo.emmy.cms.gov" }

      it { is_expected.to be true }
    end

    context "when the domain is CMS sandbox" do
      let(:domain_name) { "sandbox.emmy.cms.gov" }

      it { is_expected.to be true }
    end

    context "when the domain is a PR review app" do
      let(:domain_name) { "p-123.navapbc.cloud" }

      it { is_expected.to be true }
    end

    context "when the domain looks like a PR review app but does not match the expected pattern" do
      let(:domain_name) { "p-123.navapbc.cloud.evil.com" }

      it { is_expected.to be false }
    end

    context "when the domain is production" do
      let(:domain_name) { "reportmyincome.org" }

      it { is_expected.to be false }
    end

    context "when the domain is the CMS production host" do
      let(:domain_name) { "emmy.cms.gov" }

      it { is_expected.to be false }
    end

    context "when the domain is unknown" do
      it { is_expected.to be false }
    end
  end
end
