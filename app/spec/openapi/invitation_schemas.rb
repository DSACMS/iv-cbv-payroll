require_relative "invitation_documentation"

module InvitationSchemas
  def self.schemas
    metadata_fields = {
      individual_id: { type: :string, minLength: 1, example: "INDIVIDUAL-123", description: "Agency individual identifier. Required for V2 activity invitations." },
      first_name: { type: :string, minLength: 1, example: "Jane" },
      middle_name: { type: :string, nullable: true, example: "Alex" },
      last_name: { type: :string, minLength: 1, example: "Doe" },
      case_number: { type: :string, nullable: true, example: "EXAMPLE-123", description: "Agency case identifier." },
      date_of_birth: { type: :string, nullable: true, example: "01/15/1990", description: "MM/DD/YYYY. Echoed as supplied, not converted to an ISO date in the response." },
      doc_id: { type: :string, nullable: true, example: "EXAMPLE-DOC-123" }
    }

    schemas = {
      AgencyPartnerMetadata: {
        type: :object,
        additionalProperties: true,
        description: InvitationDocumentation.read("agency-partner-metadata"),
        anyOf: %w[Sandbox NewHampshire Louisiana Research Accenture].map { |agency| { "$ref" => "#/components/schemas/AgencyMetadata#{agency}" } }
      },
      InvitationRequest: {
        type: :object,
        additionalProperties: true,
        description: "Invitation settings and metadata for the agency identified by the API key.",
        required: %w[language agency_partner_metadata],
        properties: {
          language: {
            type: :string, pattern: "^([eE][nN]|[eE][sS])$", example: "en",
            description: "Preferred language: en (English) or es (Spanish), case insensitive. Required; omitted or unsupported values return 422. Returned in lowercase."
          },
          agency_partner_metadata: { "$ref" => "#/components/schemas/AgencyPartnerMetadata" }
        }
      },
      InvitationResponse: {
        type: :object,
        description: InvitationDocumentation.read("post-v1-invitations", section: "Response"),
        required: %w[tokenized_url expiration_date language agency_partner_metadata],
        additionalProperties: true,
        properties: {
          tokenized_url: { type: :string, format: :uri, description: "Income reporting link. Treat the token as opaque and direct the applicant to this URL unchanged." },
          expiration_date: { type: :string, format: :"date-time", description: "Expiration of tokenized_url, at the end of the day in America/New_York after the agency's configured validity period." },
          language: { type: :string, enum: %w[en es] },
          agency_partner_metadata: { "$ref" => "#/components/schemas/AgencyPartnerMetadata" }
        }
      },
      InvitationErrors: {
        type: :object,
        required: %w[errors],
        additionalProperties: true,
        properties: {
          errors: {
            type: :array, minItems: 1,
            items: {
              type: :object, required: %w[field message], additionalProperties: true,
              properties: {
                field: { type: :string, description: "Invalid field, including language or cbv_applicant.first_name. Applicant errors may use cbv_applicant or agency_partner_metadata prefixes." },
                message: { type: :string, description: "Human-readable validation message. Do not depend on the exact wording." }
              }
            }
          }
        }
      },
      V2AgencyPartnerMetadata: {
        type: :object,
        additionalProperties: true,
        description: InvitationDocumentation.read("agency-partner-metadata"),
        anyOf: %w[Sandbox NewHampshire Louisiana Research Accenture].map { |agency| { "$ref" => "#/components/schemas/V2AgencyMetadata#{agency}" } }
      },
      V2InvitationRequest: {
        type: :object,
        additionalProperties: true,
        description: "Invitation settings and metadata for the agency identified by the API key. invitation_type is selected via the URL path, not this body.",
        required: %w[language agency_partner_metadata],
        properties: {
          language: {
            type: :string, pattern: "^([eE][nN]|[eE][sS])$", example: "en",
            description: "Preferred language: en (English) or es (Spanish), case insensitive. Required; omitted or unsupported values return 422. Returned in lowercase."
          },
          verification_range: {
            type: :string, nullable: true, enum: [ "last_complete_month", "last_12_complete_months", nil ],
            description: "Reporting window for the activity invitation."
          },
          agency_partner_metadata: { "$ref" => "#/components/schemas/V2AgencyPartnerMetadata" }
        }
      },
      V2InvitationResponse: {
        type: :object,
        description: InvitationDocumentation.read("post-v2-invitations", section: "Response"),
        required: %w[tokenized_url activity_tokenized_url expiration_date language agency_partner_metadata],
        additionalProperties: true,
        properties: {
          tokenized_url: { type: :string, format: :uri, description: "Income reporting link. Treat the token as opaque and direct the applicant to this URL unchanged." },
          activity_tokenized_url: { type: :string, format: :uri, description: "Activity reporting link for the selected invitation_type." },
          expiration_date: { type: :string, format: :"date-time", description: "Expiration of tokenized_url, at the end of the day in America/New_York after the agency's configured validity period." },
          language: { type: :string, enum: %w[en es] },
          agency_partner_metadata: { "$ref" => "#/components/schemas/V2AgencyPartnerMetadata" }
        }
      },
      V2InvitationErrors: {
        type: :object,
        required: %w[errors],
        additionalProperties: true,
        description: "Validation errors for a V2 invitation request. The field attribute identifies the invalid value.",
        properties: {
          errors: {
            type: :array, minItems: 1,
            items: {
              type: :object, required: %w[field message], additionalProperties: true,
              properties: {
                field: {
                  type: :string,
                  enum: %w[language individual_id first_name last_name date_of_birth],
                  description: "Invalid field. language is a top-level request field; individual_id, first_name, last_name, and date_of_birth come from agency_partner_metadata and are validated against the agency's configured api.v2 metadata and required fields for the given invitation_type."
                },
                message: { type: :string, description: "Human-readable validation message. Do not depend on the exact wording." }
              }
            }
          }
        }
      }
    }

    {
      "Sandbox" => [ "Sandbox", %i[first_name middle_name last_name case_number date_of_birth] ],
      "NewHampshire" => [ "New Hampshire", %i[first_name middle_name last_name case_number date_of_birth] ],
      "Louisiana" => [ "Louisiana", %i[case_number date_of_birth doc_id] ],
      "Research" => [ "Research", %i[case_number date_of_birth] ],
      "Accenture" => [ "Accenture", %i[case_number] ]
    }.each do |agency, (title, fields)|
      schema_name = "AgencyMetadata#{agency}"
      schema = {
        title: schema_name,
        type: :object,
        description: "Accepted metadata for #{title}. The API ignores fields outside this schema.",
        additionalProperties: true,
        properties: metadata_fields.slice(*fields)
      }
      schema[:required] = %w[first_name last_name] if agency == "NewHampshire"
      if agency == "Louisiana"
        schema[:properties][:case_number] = metadata_fields[:case_number].merge(maxLength: 13)
      end
      schemas[schema_name] = schema

      v2_schema_name = "V2AgencyMetadata#{agency}"
      v2_fields = fields + [ :individual_id ]
      v2_schema = {
        title: v2_schema_name,
        type: :object,
        description: "Accepted V2 metadata for #{title}, including individual_id required for activity invitations. The API ignores fields outside this schema.",
        additionalProperties: true,
        properties: metadata_fields.slice(*v2_fields),
        required: %w[individual_id first_name last_name date_of_birth] & v2_fields.map(&:to_s)
      }
      if agency == "Louisiana"
        v2_schema[:properties][:case_number] = metadata_fields[:case_number].merge(maxLength: 13)
      end
      schemas[v2_schema_name] = v2_schema
    end

    schemas
  end
end
