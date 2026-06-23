module InternalEnvironment
  DOMAINS = [
    # "Dev" deployed environment
    "verify-demo.navapbc.cloud",
    # "Demo" deployed environment
    "demo.reportmyincome.org",
    # CMS-hosted environments
    "uat.emmy.cms.gov",
    "dev.emmy.cms.gov",
    "demo.emmy.cms.gov",
    "sandbox.emmy.cms.gov"
  ].freeze

  PR_REVIEW_APP_DOMAIN_PATTERN = /\Ap-\d+\.navapbc\.cloud\z/

  def self.internal?(domain_name:, rails_env:)
    return true if rails_env.development? || rails_env.test?

    DOMAINS.include?(domain_name) || domain_name.to_s.match?(PR_REVIEW_APP_DOMAIN_PATTERN)
  end
end
