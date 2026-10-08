require_relative "invitation_documentation"

module ActivityReportSchemas
  def self.schemas
    address = %i[street_address street_address_line_2 city state zip_code].index_with { nullable_string }
    contact = %i[contact_name contact_email contact_phone_number].index_with { nullable_string }
    self_attested = address.merge(
      hours: { type: :number, minimum: 0, description: "Hours reported for this month; may be zero." },
      additional_comments: nullable_string
    )
    education_term = {
      type: { type: :string, enum: %w[education] },
      school_name: nullable_string,
      enrollment_status: { type: :string, enum: NscEnrollmentTerm.enrollment_statuses.keys },
      credit_hours: { type: %w[number null], minimum: 0, description: "Academic credit hours for the term; null when not supplied." },
      term: ref("CeEducationTerm"),
      additional_comments: nullable_string
    }

    {
      CeActivityReport: object(%w[schema_version confirmation_code completed_at agency_partner_metadata ce_report], {
        schema_version: { type: :string, pattern: '^\d+\.\d+\.\d+$', example: "1.0.0" },
        confirmation_code: { type: :string, description: "Confirmation code shared with the applicant." },
        completed_at: { type: :string, format: :"date-time", description: "UTC time the applicant completed the report." },
        agency_partner_metadata: ref("AgencyPartnerMetadata"),
        ce_report: ref("CeReport")
      }).merge(description: InvitationDocumentation.read("ce-activity-report", section: "Model")),
      CeReport: object(%w[report_variantreview_period documents activities], {
        report_variant: { type: :string, enum: %w[employment community_engagement] },
        review_period: ref("CeReviewPeriod"),
        documents: { type: :array, items: ref("CeDocument") },
        activities: ref("CeActivities")
      }),
      CeReviewPeriod: object(%w[start_month end_month], {
        start_month: month,
        end_month: month
      }).merge(description: "Inclusive calendar months covered by the report."),
      CeDocument: object(%w[document_id document_name file_type], {
        document_id: { type: :string, description: "Attachment identifier referenced by an activity's document_ids." },
        document_name: { type: :string, description: "Filename used when transmitting the document separately." },
        file_type: { type: :string, description: "File extension without the leading dot." }
      }),
      CeActivities: object(%w[community_service work_program employment education], {
        community_service: months("CeCommunityServiceActivity"),
        work_program: months("CeWorkProgramActivity"),
        employment: months("CeEmploymentActivity"),
        education: months("CeEducationActivity")
      }),
      CeActivity: object(%w[type month data_source document_ids], {
        type: { type: :string, enum: %w[community_service work_program employment education] },
        month: month,
        data_source: { type: :string, enum: %w[self_attested validated verified verified_enrollment_only] },
        document_ids: { type: :array, items: { type: :string } }
      }),
      CeCommunityServiceActivity: activity(%w[hours], self_attested.merge(
        type: { type: :string, enum: %w[community_service] },
        data_source: { type: :string, enum: %w[self_attested] },
        organization_name: nullable_string,
        coordinator_name: nullable_string,
        coordinator_email: nullable_string,
        coordinator_phone_number: nullable_string
      )),
      CeWorkProgramActivity: activity(%w[hours], self_attested.merge(contact).merge(
        type: { type: :string, enum: %w[work_program] },
        data_source: { type: :string, enum: %w[self_attested] },
        organization_name: nullable_string,
        program_name: nullable_string
      )),
      CeEmploymentActivity: {
        description: "One employer's activity in the enclosing month, either self-attested or validated payroll data.",
        oneOf: [ ref("CeSelfAttestedEmploymentActivity"), ref("CeValidatedEmploymentActivity") ],
        discriminator: {
          propertyName: "data_source",
          mapping: {
            self_attested: "#/components/schemas/CeSelfAttestedEmploymentActivity",
            validated: "#/components/schemas/CeValidatedEmploymentActivity"
          }
        }
      },
      CeSelfAttestedEmploymentActivity: activity(%w[employer_name employment_type is_self_employed hours gross_income], self_attested.merge(contact).merge(
        type: { type: :string, enum: %w[employment] },
        data_source: { type: :string, enum: %w[self_attested] },
        employer_name: { type: :string },
        employer_address: nullable_string.merge(description: "Combined address, also supplied as individual address fields."),
        employment_type: { type: :string, enum: %w[w2 self_employed unpaid], description: "Paid work, paid self-employment, or unpaid/in-kind work." },
        is_self_employed: { type: :boolean, description: "Employer contact fields are null when true." },
        gross_income: { type: :number, minimum: 0, description: "Self-attested monthly gross income in dollars, including cents as a decimal." }
      )),
      CeValidatedEmploymentActivity: activity(%w[applicant_full_name employer_name paystubs], {
        type: { type: :string, enum: %w[employment] },
        data_source: { type: :string, enum: %w[validated], description: "Used for both Argyle and Pinwheel." },
        applicant_full_name: nullable_string,
        applicant_ssn: nullable_string.merge(pattern: '^XXX-XX-\d{4}$', description: "Masked SSN, when available."),
        applicant_extra_comments: nullable_string,
        employer_name: nullable_string,
        employer_phone: nullable_string,
        employer_address: nullable_string,
        employment_status: nullable_enum(%w[employed inactive terminated]),
        employment_type: nullable_enum(%w[w2 gig]),
        employment_start_date: nullable_string.merge(format: :date),
        employment_end_date: nullable_string.merge(format: :date),
        pay_frequency: nullable_enum(%w[daily weekly biweekly semimonthly monthly quarterly variable]),
        compensation_amount: cents(nullable: true),
        compensation_unit: nullable_enum(%w[hourly daily weekly biweekly semimonthly monthly annual salary per_mile semiweekly variable]),
        paystubs: { type: :array, minItems: 1, items: ref("CePaystub"), description: "Only payments dated within the enclosing month and review period. Grouped by pay_date, not pay period." }
      }),
      CeEducationActivity: {
        description: "Education in the enclosing month: self-attested credits, verified NSC enrollment, or verified enrollment with self-attested credits.",
        oneOf: [ ref("CeSelfAttestedEducationActivity"), ref("CeVerifiedEducationActivity"), ref("CeVerifiedEnrollmentOnlyEducationActivity") ],
        discriminator: {
          propertyName: "data_source",
          mapping: {
            self_attested: "#/components/schemas/CeSelfAttestedEducationActivity",
            verified: "#/components/schemas/CeVerifiedEducationActivity",
            verified_enrollment_only: "#/components/schemas/CeVerifiedEnrollmentOnlyEducationActivity"
          }
        }
      },
      CeSelfAttestedEducationActivity: activity(%w[school_name hours], self_attested.merge(contact).merge(
        type: { type: :string, enum: %w[education] },
        data_source: { type: :string, enum: %w[self_attested] },
        school_name: { type: :string },
        hours: { type: :number, minimum: 0, description: "Academic credit hours reported for this month; may be zero." }
      )),
      CeVerifiedEducationActivity: activity(%w[school_name enrollment_status term], education_term.merge(
        data_source: { type: :string, enum: %w[verified], description: "NSC-verified enrollment." }
      )),
      CeVerifiedEnrollmentOnlyEducationActivity: activity(%w[school_name hours enrollment_status term], self_attested.merge(contact).merge(education_term).merge(
        data_source: { type: :string, enum: %w[verified_enrollment_only], description: "NSC-verified enrollment with self-attested academic credits." },
        hours: { type: %w[number null], minimum: 0, description: "Self-attested academic credit hours for the term, also supplied as credit_hours; null when not reported." }
      )),
      CeEducationTerm: object(%w[start_month end_month], {
        start_month: month,
        end_month: month
      }).merge(description: "Original enrollment term dates, retained in each applicable reporting month, including summer carryover."),
      CePaystub: object(%w[pay_date pay_gross], {
        pay_date: { type: :string, format: :date },
        pay_period_start: nullable_string.merge(format: :date),
        pay_period_end: nullable_string.merge(format: :date),
        pay_gross: cents.merge(description: "Gross pay in cents. Missing gross pay uses the income report's zero fallback."),
        pay_gross_ytd: cents(nullable: true),
        pay_net: cents(nullable: true),
        hours_paid: { type: %w[number null], description: "Hours paid, including overtime." },
        deductions: { type: :array, items: ref("CePaystubDeduction") },
        gross_pay_list: { type: :array, items: ref("CeGrossPayComponent") }
      }),
      CePaystubDeduction: object(%w[category tax amount], {
        category: nullable_string,
        tax: { type: :string, enum: %w[pre_tax post_tax unknown] },
        amount: cents(nullable: true)
      }),
      CeGrossPayComponent: object(%w[type amount], {
        type: { type: :string, enum: %w[base benefits bereavement bonus commission disability double_overtime employer_contribution fare holiday hourly life_insurance meal_comp medical other overtime parental premium pto retirement retro_pay salary shift_differential sick stock tips unpaid vacation] },
        amount: cents
      })
    }
  end

  def self.object(required, properties)
    { type: :object, additionalProperties: true, properties: properties }.tap do |schema|
      schema[:required] = required if required.any?
    end
  end

  def self.ref(name)
    { "$ref" => "#/components/schemas/#{name}" }
  end

  def self.activity(required, properties)
    { allOf: [ ref("CeActivity"), object(required, properties) ] }
  end

  def self.months(name)
    {
      type: :object,
      description: "Map of YYYY-MM calendar months to activity arrays. Months with no reported activity are omitted; no activities is an empty object.",
      additionalProperties: true,
      patternProperties: { '^\d{4}-\d{2}$' => { type: :array, items: ref(name) } }
    }
  end

  def self.month
    { type: :string, pattern: '^\d{4}-\d{2}$', description: "Calendar month as YYYY-MM." }
  end

  def self.nullable_string
    { type: %w[string null] }
  end

  def self.nullable_enum(values)
    nullable_string.merge(enum: [ *values, nil ])
  end

  def self.cents(nullable: false)
    { type: nullable ? %w[integer null] : :integer, description: "Amount in cents (12345 represents $123.45)." }
  end
end
