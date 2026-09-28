module InvitationDocumentation
  SITE_URL = "https://CMS-Enterprise.github.io/emmy-app/index.html".freeze

  def self.read(name)
    Rails.root.join("../docs/api", "#{name}.md").read.strip
  end
end
