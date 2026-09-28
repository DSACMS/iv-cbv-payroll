module InvitationDocumentation
  SITE_URL = "https://CMS-Enterprise.github.io/emmy-app/index.html".freeze

  def self.read(name, section: nil)
    markdown = Rails.root.join("../docs/api", "#{name}.md").read
    return markdown.strip unless section

    # Endpoint documents use level-two headings for independently included sections.
    content = markdown.split(/^## #{Regexp.escape(section)}[ \t]*\r?$/, 2)[1]
    raise ArgumentError, "Missing section #{section.inspect} in docs/api/#{name}.md" unless content

    content.split(/^## /, 2).first.to_s.strip
  end
end
