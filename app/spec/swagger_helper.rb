require "rails_helper"
require_relative "openapi/invitation_schemas"
require_relative "openapi/activity_report_schemas"
require_relative "openapi/activity_report_webhook"
require_relative "openapi/document_webhook"

RSpec.configure do |config|
  config.openapi_root = Rails.root.join("tmp/api-docs").to_s
  config.openapi_format = :json
  config.openapi_specs = {
    "openapi.json" => {
      openapi: "3.1.0",
      info: {
        title: "Emmy Platform API Documentation",
        version: "v1",
        description: InvitationDocumentation.read("introduction")
      },
      servers: [
        { url: "https://verify-demo.navapbc.cloud", description: "Dev environment" },
        { url: "https://demo.reportmyincome.org", description: "Demo environment" }
      ],
      externalDocs: { description: "Emmy Platform API Documentation", url: InvitationDocumentation::SITE_URL },
      tags: [
        { name: "Invitations", description: "Generate links for an applicant to begin reporting." },
        { name: "Overview", description: InvitationDocumentation.read("receiving-data/README", section: "Overview") },
        { name: "Report delivery flow", description: InvitationDocumentation.read("receiving-data/report-delivery-flow") },
        { name: "Webhook signatures", description: InvitationDocumentation.read("receiving-data/webhook-signatures") },
        { name: "Retry logic", description: InvitationDocumentation.read("receiving-data/retry-logic") },
        { name: ActivityReportWebhook::TAG, description: InvitationDocumentation.read("receiving-data/ce-activity-json", section: "Overview") },
        { name: "Income Reports (JSON)", description: InvitationDocumentation.read("receiving-data/income-reports") },
        { name: DocumentWebhook::TAG, description: InvitationDocumentation.read("receiving-data/pdf-transmission", section: "Overview") }
      ],
      "x-tagGroups" => [
        { name: "Emmy API", tags: [ "Invitations" ] },
        { name: "Receiving data from the Emmy Platform", tags: [ "Overview", "Report delivery flow", "Webhook signatures", "Retry logic", ActivityReportWebhook::TAG, "Income Reports (JSON)", DocumentWebhook::TAG ] }
      ],
      paths: {},
      webhooks: {
        ActivityReportWebhook::PATH => { post: ActivityReportWebhook.operation },
        DocumentWebhook::PATH => { post: DocumentWebhook.operation }
      },
      components: {
        securitySchemes: {
          bearerAuth: { type: :http, scheme: :bearer, description: "Agency API key. Send Authorization: Bearer API_KEY. The key determines the agency; do not send a client_agency_id." }
        },
        schemas: InvitationSchemas.schemas.merge(ActivityReportSchemas.schemas)
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
      request_schema = metadata[:operation][:parameters].find { |parameter| parameter[:in] == :body }.fetch(:schema)
      schema_name = request_schema.fetch("$ref").split("/").last
      errors = document.schema(schema_name).validate(invitation.deep_stringify_keys).to_a
      expect(errors).to be_empty, errors.inspect
      metadata[:operation][:request_examples] ||= []
      metadata[:operation][:request_examples] << { name: name, summary: summary, value: invitation }
    end
  end
end
