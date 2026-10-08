require_relative "invitation_documentation"

module InvitationSchemas
  def self.schemas
    metadata_fields = {
      individual_id: { type: :string, minLength: 1, example: "INDIVIDUAL-123", description: "Agency individual identifier. Required for V2 activity invitations." },
      first_name: { type: :string, minLength: 1, example: "Jane" },
      middle_name: { type: %w[string null], example: "Alex" },
      last_name: { type: :string, minLength: 1, example: "Doe" },
      case_number: { type: %w[string null], example: "EXAMPLE-123", description: "Agency case identifier." },
      date_of_birth: { type: %w[string null], example: "01/15/1990", description: "MM/DD/YYYY. Echoed as supplied, not converted to an ISO date in the response." },
      doc_id: { type: %w[string null], example: "EXAMPLE-DOC-123" }
    }

    schemas = {
      AgencyPartnerMetadata: {
        type: :object,
        additionalProperties: true,
        description: InvitationDocumentation.read("agency-partner-metadata"),
        anyOf: %w[Sandbox NewHampshire Louisiana Research Accenture].map { |agency| { "$ref" => "#/components/schemas/AgencyMetadata#{agency}" } }
      },
      AgencyPartnerMetadataV2: {
        type: :object,
        additionalProperties: true,
        description: InvitationDocumentation.read("agency-partner-metadata"),
        anyOf: %w[community_engagement employment].flat_map do |invitation_type|
          %w[Sandbox NewHampshire Louisiana Research Accenture].map do |agency|
            { "$ref" => "#/components/schemas/V2AgencyMetadata#{agency}#{invitation_type.camelize}" }
          end
        end
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
      InvitationRequestV2: {
        type: :object,
        additionalProperties: true,
        description: "Invitation settings and metadata for the agency identified by the API key. invitation_type is selected via the URL path, not this body.",
        required: %w[language verification_range agency_partner_metadata],
        properties: {
          language: {
            type: :string, pattern: "^([eE][nN]|[eE][sS])$", example: "en",
            description: "Preferred language: en (English) or es (Spanish), case insensitive. Required; omitted or unsupported values return 422. Returned in lowercase."
          },
          verification_range: {
            type: :string, enum: [ "last_complete_month", "last_12_complete_months" ],
            description: "Reporting window for the activity invitation."
          },
          agency_partner_metadata: { "$ref" => "#/components/schemas/AgencyPartnerMetadataV2" }
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
      InvitationResponseV2: {
        type: :object,
        description: InvitationDocumentation.read("post-v2-invitations", section: "Response"),
        required: %w[tokenized_url activity_tokenized_url expiration_date language agency_partner_metadata],
        additionalProperties: true,
        properties: {
          tokenized_url: { type: :string, format: :uri, description: "Income reporting link. Treat the token as opaque and direct the applicant to this URL unchanged." },
          activity_tokenized_url: { type: :string, format: :uri, description: "Activity reporting link for the selected invitation_type." },
          expiration_date: { type: :string, format: :"date-time", description: "Expiration of tokenized_url, at the end of the day in America/New_York after the agency's configured validity period." },
          language: { type: :string, enum: %w[en es] },
          agency_partner_metadata: { "$ref" => "#/components/schemas/AgencyPartnerMetadataV2" }
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
      InvitationErrorsV2: {
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
                  description: "Invalid request field. Applicant validation errors may use an agency_partner_metadata prefix."
                },
                message: { type: :string, description: "Human-readable validation message. Do not depend on the exact wording." }
              }
            }
          }
        }
      }
    }

    {
      "Sandbox" => [ "sandbox", "Sandbox", %i[first_name middle_name last_name case_number date_of_birth] ],
      "NewHampshire" => [ "nh_dhhs", "New Hampshire", %i[first_name middle_name last_name case_number date_of_birth] ],
      "Louisiana" => [ "la_ldh", "Louisiana", %i[case_number date_of_birth doc_id] ],
      "Research" => [ "research", "Research", %i[case_number date_of_birth] ],
      "Accenture" => [ "accenture", "Accenture", %i[case_number] ]
    }.each do |agency, (agency_id, title, fields)|
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

      client_agency = Rails.application.config.client_agencies[agency_id] ||
        raise(KeyError, "No client agency config for #{agency_id.inspect}")

      %w[community_engagement employment].each do |invitation_type|
        v2_schema_name = "AgencyMetadataV2#{agency}#{invitation_type.camelize}"
        v2_fields = client_agency.api_metadata(invitation_type)
        v2_schema = {
          title: v2_schema_name,
          type: :object,
          description: "Accepted V2 metadata for #{title}'s #{invitation_type.humanize.downcase} invitations. The API ignores fields outside this schema.",
          additionalProperties: true,
          properties: v2_fields.to_h { |field| [ field, metadata_fields.fetch(field) ] },
          required: client_agency.api_required_metadata(invitation_type).map(&:to_s)
        }
        schemas[v2_schema_name] = v2_schema
      end
    end

    schemas
  end
end
