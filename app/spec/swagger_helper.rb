require "rails_helper"
require_relative "openapi/invitation_schemas"

RSpec.configure do |config|
  config.openapi_root = Rails.root.join("tmp/api-docs").to_s
  config.openapi_format = :json
  config.openapi_specs = {
    "openapi.json" => {
      openapi: "3.0.3",
      info: {
        title: "Emmy Tokenized Link API",
        version: "v1",
        description: "Create personalized links for applicants to report income and community engagement activities. Authenticate using an agency API key. All examples use synthetic data. This reference covers POST /api/v1/invitations; V2 invitations and report transmission payloads are documented separately."
      },
      servers: [ { url: "https://{agencyHost}", description: "Use the environment hostname provided during onboarding.", variables: { agencyHost: { default: "agency.example.org" } } } ],
      tags: [ { name: "Invitations", description: "Generate links for an applicant to begin reporting." } ],
      paths: {},
      components: {
        securitySchemes: {
          bearerAuth: { type: :http, scheme: :bearer, description: "Agency API key. Send Authorization: Bearer API_KEY. The key determines the agency; do not send a client_agency_id." }
        },
        schemas: InvitationSchemas.schemas
      }
    }
  }

  # Capture examples from real requests. Never capture Authorization headers.
  config.after(:each, :openapi_example) do |example|
    next if example.exception

    metadata = example.metadata
    name = metadata.fetch(:openapi_example)
    summary = metadata.fetch(:example_summary)
    mime = response.media_type
    value = mime == "application/json" ? response.parsed_body : response.body
    content = metadata[:response][:content] ||= {}
    media = content[mime] ||= {}
    media[:examples] ||= {}
    media[:examples][name] = { summary: summary, value: value }

    if response.status == 201
      document = JSONSchemer.openapi(JSON.parse(config.openapi_specs.fetch("openapi.json").to_json))
      errors = document.schema("InvitationRequest").validate(invitation.deep_stringify_keys).to_a
      expect(errors).to be_empty, errors.inspect
      metadata[:operation][:request_examples] ||= []
      metadata[:operation][:request_examples] << { name: name, summary: summary, value: invitation }
    end
  end
end
