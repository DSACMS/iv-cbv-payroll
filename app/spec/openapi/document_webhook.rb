require_relative "invitation_documentation"

module DocumentWebhook
  TAG = "Documents".freeze
  PATH = "/api/v1/documents".freeze

  def self.operation
    {
      tags: [ TAG ],
      operationId: "receiveDocument",
      summary: "Receive a Document",
      description: InvitationDocumentation.read("receiving-data/pdf-transmission", section: "Receive a Document")
        .sub("(webhook-signatures.md)", "(#tag/webhook-signatures)"),
      servers: [ { url: "https://agency.example.org", description: "Agency system (replace with your receiver URL)" } ],
      security: [],
      parameters: [
        { name: "Content-Type", in: :header, required: true,
          description: InvitationDocumentation.read("receiving-data/pdf-transmission", section: "Content-Type"),
          schema: { type: :string, example: "application/pdf" } },
        { name: "Content-Length", in: :header, required: true,
          description: InvitationDocumentation.read("receiving-data/pdf-transmission", section: "Content-Length"),
          schema: { type: :integer, minimum: 0 } },
        { name: "X-IVAAS-Timestamp", in: :header, required: true,
          description: "Unix timestamp used when signing the request.", schema: { type: :string, pattern: '^\d+$' } },
        { name: "X-IVAAS-Signature", in: :header, required: true,
          description: 'HMAC-SHA512 hexdigest of `"<timestamp>:<request body>"`, keyed with the agency API key.',
          schema: { type: :string, pattern: '^[0-9a-f]{128}$' } },
        { name: "X-IVAAS-Confirmation-Code", in: :header, required: true,
          description: "Confirmation code of the submitted report.", schema: { type: :string, example: "SANDBOX123" } }
      ],
      requestBody: {
        required: true,
        description: InvitationDocumentation.read("receiving-data/pdf-transmission", section: "Request body"),
        content: { "*/*" => { schema: { type: :string, format: :binary } } }
      },
      responses: {
        "200" => {
          description: InvitationDocumentation.read("receiving-data/pdf-transmission", section: "Response and error handling")
            .sub("(retry-logic.md)", "(#tag/retry-logic)")
        }
      }
    }
  end
end
