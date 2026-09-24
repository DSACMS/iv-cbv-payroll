require_relative "invitation_documentation"

module InvitationSchemas
  def self.schemas
    metadata_fields = {
      first_name: { type: :string, minLength: 1, example: "Jane" },
      middle_name: { type: :string, nullable: true, example: "Alex" },
      last_name: { type: :string, minLength: 1, example: "Doe" },
      case_number: { type: :string, nullable: true, example: "EXAMPLE-123", description: "Agency case identifier." },
      date_of_birth: { type: :string, nullable: true, example: "01/15/1990", description: "MM/DD/YYYY. Echoed as supplied, not converted to an ISO date in the response." },
      doc_id: { type: :string, nullable: true, example: "EXAMPLE-DOC-123" }
    }

    schemas = {
      AgencyPartnerMetadata: {
        description: InvitationDocumentation::METADATA,
        anyOf: %w[Sandbox NewHampshire Louisiana Research Accenture].map { |agency| { "$ref" => "#/components/schemas/#{agency}PartnerMetadata" } }
      },
      InvitationRequest: {
        type: :object,
        description: "Invitation settings and metadata for the agency identified by the API key.",
        required: %w[language agency_partner_metadata],
        properties: {
          language: {
            type: :string, pattern: "^([eE][nN]|[eE][sS])$", example: "en",
            description: "Preferred language: en (English) or es (Spanish), case insensitive. Required; omitted or unsupported values return 422. Returned in lowercase."
          },
          agency_partner_metadata: { "$ref" => "#/components/schemas/AgencyPartnerMetadata" },
          activities: {
            type: :array,
            description: "Optional prefilled activities. Ignored unless prefilled activities are enabled for the agency. A nonempty valid list creates an activity invitation in addition to the income invitation. Each type must also be enabled for the agency.",
            items: { oneOf: %w[Volunteering Employment Education JobTraining].map { |type| { "$ref" => "#/components/schemas/#{type}InvitationActivity" } } }
          }
        }
      },
      InvitationResponse: {
        type: :object,
        description: InvitationDocumentation::LINK_LIFETIME,
        required: %w[tokenized_url expiration_date language agency_partner_metadata],
        additionalProperties: false,
        properties: {
          tokenized_url: { type: :string, format: :uri, description: "Income reporting link. Treat the token as opaque and direct the applicant to this URL unchanged." },
          expiration_date: { type: :string, format: :"date-time", description: "Expiration of tokenized_url, at the end of the day in America/New_York after the agency's configured validity period. Does not describe the activity link's lifetime." },
          language: { type: :string, enum: %w[en es] },
          agency_partner_metadata: { "$ref" => "#/components/schemas/AgencyPartnerMetadata" },
          activity_tokenized_url: { type: :string, format: :uri, description: "Community engagement reporting link. Present only when a nonempty activities list is accepted. Activity invitations currently have no time-based expiration." }
        }
      },
      InvitationErrors: {
        type: :object,
        required: %w[errors],
        additionalProperties: false,
        properties: {
          errors: {
            type: :array, minItems: 1,
            items: {
              type: :object, required: %w[field message], additionalProperties: false,
              properties: {
                field: { type: :string, description: "Invalid field, including language, cbv_applicant.first_name, or activities[0].organization_name. Applicant errors may use cbv_applicant or agency_partner_metadata prefixes." },
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
      schema = {
        title: title,
        type: :object,
        description: "Accepted metadata for #{title}. The API ignores fields outside this schema.",
        additionalProperties: false,
        properties: metadata_fields.slice(*fields)
      }
      schema[:required] = %w[first_name last_name] if fields.include?(:first_name)
      if agency == "Louisiana"
        schema[:properties][:case_number] = metadata_fields[:case_number].merge(maxLength: 13)
      end
      schemas["#{agency}PartnerMetadata"] = schema
    end

    address = %w[street_address street_address_line_2 city state zip_code].index_with { { type: :string } }
    contact = %w[contact_name contact_email contact_phone_number].index_with { { type: :string } }
    coordinator = %w[coordinator_name coordinator_email coordinator_phone_number].index_with { { type: :string } }

    {
      "Volunteering" => [ "volunteering", %w[organization_name], coordinator ],
      "Employment" => [ "employment", %w[employer_name], contact.merge("is_self_employed" => { type: :boolean }) ],
      "Education" => [ "education", %w[school_name], contact ],
      "JobTraining" => [ "job_training", %w[program_name organization_name], contact.merge("organization_address" => { type: :string }) ]
    }.each do |name, (type, required, extra)|
      month_properties = {
        month: { type: :string, format: :date, example: "2026-08-01", description: "A date in the agency's application reporting window, calculated when the invitation is created. Use the first day of the month. Example assumes an invitation created in September 2026." },
        hours: { type: :number, example: 12.5, description: type == "education" ? "Monthly credit hours." : "Monthly activity hours." }
      }
      if type == "employment"
        month_properties[:gross_income] = { type: :number, example: 1250.50, description: "Monthly gross income in dollars." }
      end

      schemas["#{name}InvitationActivity"] = {
        type: :object,
        required: [ "type", *required ],
        properties: address.merge(extra).merge(required.index_with { { type: :string, minLength: 1 } }).merge(
          type: { type: :string, enum: [ type ] },
          months: {
            type: :array,
            description: "Optional monthly values to prefill. This endpoint validates the month against the reporting window; hours and income are validated later in the reporting flow.",
            items: { type: :object, required: %w[month], properties: month_properties }
          }
        )
      }
    end

    schemas
  end
end
