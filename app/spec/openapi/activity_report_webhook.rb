require_relative "invitation_documentation"

module ActivityReportWebhook
  TAG = "CE Activity Reports".freeze
  PATH = "/api/v1/ce-activity-report".freeze

  def self.operation
    {
      tags: [ TAG ],
      operationId: "receiveCeActivityReport",
      summary: "Receive a CE Activity Report (JSON)",
      description: InvitationDocumentation.read("receiving-data/ce-activity-json")
        .sub("(webhook-signatures.md)", "(#tag/webhook-signatures)"),
      servers: [ { url: "https://agency.example.org", description: "Agency system (replace with your receiver URL)" } ],
      security: [],
      parameters: [
        { name: "X-IVAAS-Timestamp", in: :header, required: true,
          description: "Unix timestamp used when signing the request.", schema: { type: :string, pattern: '^\d+$' } },
        { name: "X-IVAAS-Signature", in: :header, required: true,
          description: 'HMAC-SHA512 hexdigest of `"<timestamp>:<request body>"`, keyed with the agency API key.',
          schema: { type: :string, pattern: '^[0-9a-f]{128}$' } },
        { name: "X-IVAAS-Confirmation-Code", in: :header, required: true,
          description: "The confirmation_code from the request body.", schema: { type: :string, example: "SANDBOX123" } }
      ],
      requestBody: {
        required: true,
        content: { "application/json" => { schema: { "$ref" => "#/components/schemas/CeActivityReport" } } }
      },
      responses: {
        "200" => {
          description: InvitationDocumentation.read("receiving-data/ce-activity-json", section: "Response"),
          content: {
            "application/json" => {
              schema: {
                type: :object, additionalProperties: true,
                properties: {
                  status: { type: :string }, confirmation_code: { type: :string },
                  received_at: { type: :string, format: :"date-time" },
                  schema_version_received: { type: :string }, unrecognized_fields_detected: { type: :boolean }
                }
              },
              examples: { received: { value: JSON.parse(InvitationDocumentation.code_block("receiving-data/ce-activity-json", section: "Response", language: "json")) } }
            }
          }
        }
      }
    }
  end
end
