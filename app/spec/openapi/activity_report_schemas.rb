require_relative "invitation_documentation"

module ActivityReportSchemas
  def self.schemas
    address = {
      street_address: nullable_string.merge(description: "Street address of the organization, employer, or school."),
      street_address_line_2: nullable_string.merge(description: "Additional street address information, such as an apartment or suite."),
      city: nullable_string.merge(description: "City of the organization, employer, or school."),
      state: nullable_string.merge(description: "State of the organization, employer, or school."),
      zip_code: nullable_string.merge(description: "ZIP code of the organization, employer, or school.")
    }
    contact = {
      contact_name: nullable_string.merge(description: "Name of the contact at the work program, employer, or school."),
      contact_email: nullable_string.merge(description: "Email address of the contact at the work program, employer, or school."),
      contact_phone_number: nullable_string.merge(description: "Phone number of the contact at the work program, employer, or school.")
    }
    comments = nullable_string.merge(description: "Optional free-text comments the applicant added at the review step.")
    self_attested = address.merge(
      hours: { type: :number, minimum: 0, description: "Decimal hours (10,2) reported for this activity in the enclosing month; may be zero. Education variants use academic credit hours instead." },
      additional_comments: comments
    )
    education_term = {
      education_type: education_type,
      type: { type: :string, enum: %w[education] },
      school_name: nullable_string.merge(description: "School name from the NSC enrollment term; null when unavailable."),
      enrollment_status: { type: :string, enum: NscEnrollmentTerm.enrollment_statuses.keys, description: "NSC enrollment status for this term, including unknown when the status is unavailable." },
      credit_hours: { type: %w[number null], minimum: 0, description: "Academic credits for the term, reported by the applicant where needed. Fractions are preserved; unknown credits stay null. NSC does not provide academic credits, so this is null for verified enrollment." },
      term: ref("CeEducationTerm").merge(description: "Original enrollment term, with required start_month and end_month in YYYY-MM format."),
      additional_comments: comments
    }

    {
      CeActivityReport: object(%w[schema_version confirmation_code completed_at agency_partner_metadata ce_report], {
        schema_version: { type: :string, pattern: '^\d+\.\d+\.\d+$', example: "1.0.0", description: "Semantic version of the CE compliance specification this payload conforms to." },
        confirmation_code: { type: :string, description: "Unique code assigned when the report was completed, shared with the applicant and used to debug report processing errors." },
        completed_at: { type: :string, format: :"date-time", description: "UTC time the applicant completed the report, in ISO 8601 format." },
        agency_partner_metadata: ref("AgencyPartnerMetadata").merge(description: "Agency-specific fields used to associate the report with the correct case, as agreed in the integration plan and shared with the Income Report API. Examples include case_number (string), date_of_birth (date string), and doc_id (string); which fields are required depends on the agency."),
        ce_report: ref("CeReport").merge(description: "Community engagement report containing the review period, supporting document metadata, and activities.")
      }).merge(description: InvitationDocumentation.read("receiving-data/ce-activity-json", section: "Model")),
      CeReport: object(%w[report_variant review_period documents activities], {
        report_variant: { type: :string, enum: %w[employment community_engagement], description: "Reporting flow used to complete this report." },
        review_period: ref("CeReviewPeriod").merge(description: "Full date range covered by this CE compliance determination, expressed as inclusive calendar months."),
        documents: { type: :array, items: ref("CeDocument"), description: "All supporting documents uploaded for the activities in this report. The files are transmitted separately by the document transmission integration; this array describes what to expect." },
        activities: ref("CeActivities").merge(description: "Activities grouped first by type, then by reporting month in YYYY-MM format.")
      }).merge(description: "The report's review period, supporting documents, and reported activities."),
      CeReviewPeriod: object(%w[start_month end_month], {
        start_month: month.merge(description: "First calendar month of the review period, inclusive, in YYYY-MM format."),
        end_month: month.merge(description: "Last calendar month of the review period, inclusive, in YYYY-MM format.")
      }).merge(description: "Inclusive calendar months covered by the report."),
      CeDocument: object(%w[document_id document_name file_type], {
        document_id: { type: :string, description: "Identifier based on the Emmy Active Storage attachment ID, referenced by an activity's document_ids." },
        document_name: { type: :string, description: "Filename used when transmitting the document separately." },
        file_type: { type: :string, description: "File extension without the leading dot." }
      }).merge(description: "Metadata for a supporting document. The document itself is transmitted separately."),
      CeActivities: object(%w[community_service work_program employment education], {
        community_service: months("CeCommunityServiceActivity"),
        work_program: months("CeWorkProgramActivity"),
        employment: months("CeEmploymentActivity"),
        education: months("CeEducationActivity")
      }).merge(description: "Keys are activity types, each containing a map of YYYY-MM months to activity arrays. Months with no reported activity are omitted; an activity type with no activities is an empty object. Activities spanning several months appear under each applicable month."),
      CeActivity: object(%w[type month data_source document_ids], {
        type: { type: :string, enum: %w[community_service work_program employment education], description: "Activity type, matching the enclosing activity-type key." },
        month: month.merge(description: "Calendar month this activity applies to in YYYY-MM format; repeats the enclosing month key."),
        data_source: { type: :string, enum: %w[self_attested validated verified verified_enrollment_only], description: "Origin of the activity data: self_attested for manually reported activities, validated for linked Argyle or Pinwheel payroll, verified for NSC enrollment, or verified_enrollment_only for NSC enrollment with self-attested credits." },
        document_ids: { type: :array, items: { type: :string }, description: "Supporting document_id values from the report's documents array. Empty for linked payroll; self-attested documents are referenced from their own activities." }
      }).merge(description: "Fields shared by all activity entries in the enclosing reporting month."),
      CeCommunityServiceActivity: activity(%w[hours], self_attested.merge(
        type: { type: :string, enum: %w[community_service] },
        data_source: { type: :string, enum: %w[self_attested] },
        organization_name: nullable_string.merge(description: "Full, official name of the community service organization."),
        coordinator_name: nullable_string.merge(description: "Coordinator or supervisor the applicant worked most closely with."),
        coordinator_email: nullable_string.merge(description: "Email address of the coordinator or supervisor."),
        coordinator_phone_number: nullable_string.merge(description: "Phone number of the coordinator or supervisor.")
      )),
      CeWorkProgramActivity: activity(%w[hours], self_attested.merge(contact).merge(
        type: { type: :string, enum: %w[work_program] },
        data_source: { type: :string, enum: %w[self_attested] },
        organization_name: nullable_string.merge(description: "Organization or provider running the work or training program."),
        program_name: nullable_string.merge(description: "Full name of the work program.")
      )),
      CeEmploymentActivity: {
        description: "One employer's activity in the enclosing month, either self-attested or validated payroll data. Employment follows the September 4 specification's JSON examples: has_other_jobs and income_summary are omitted, while the CE envelope and review_period are preserved.",
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
        employer_name: { type: :string, description: "Name of the employer or business." },
        employer_address: nullable_string.merge(description: "Combined address, also supplied as individual address fields."),
        employment_type: { type: :string, enum: %w[w2 self_employed unpaid], description: "w2 for paid work, self_employed for paid self-employment, or unpaid for unpaid or in-kind work." },
        is_self_employed: { type: :boolean, description: "Whether the applicant marked the work as self-employment. Employer contact fields are null when true." },
        gross_income: { type: :number, minimum: 0, description: "Self-attested monthly gross income in dollars, including cents as a decimal." }
      )).merge(description: "Published self-attested work appears once per reported month, including months with zero hours or income. Draft activities are excluded. Includes address components, applicant comments, monthly hours, and supporting document IDs. Employer contact details are null for self-employment."),
      CeValidatedEmploymentActivity: activity(%w[applicant_full_name employer_name paystubs], {
        type: { type: :string, enum: %w[employment] },
        data_source: { type: :string, enum: %w[validated], description: "Used for both Argyle and Pinwheel." },
        applicant_full_name: nullable_string.merge(description: "Applicant's full name from the payroll provider."),
        applicant_ssn: nullable_string.merge(pattern: '^XXX-XX-\d{4}$', description: "Masked SSN, when available."),
        applicant_extra_comments: nullable_string.merge(description: "Applicant's comments about this employment."),
        employer_name: nullable_string.merge(description: "Employer name from the payroll provider."),
        employer_phone: nullable_string.merge(description: "Employer phone number from the payroll provider."),
        employer_address: nullable_string.merge(description: "Employer address from the payroll provider."),
        employment_status: nullable_enum(%w[employed inactive terminated]).merge(description: "Employment status reported by the payroll provider."),
        employment_type: nullable_enum(%w[w2 gig]).merge(description: "Payroll employment classification: W-2 or gig work."),
        employment_start_date: nullable_string.merge(format: :date, description: "Employment start date reported by the payroll provider."),
        employment_end_date: nullable_string.merge(format: :date, description: "Employment end date reported by the payroll provider."),
        pay_frequency: nullable_enum(%w[daily weekly biweekly semimonthly monthly quarterly variable]).merge(description: "How often the applicant is paid."),
        compensation_amount: cents(nullable: true).merge(description: "Compensation rate in cents, per compensation_unit; null when unavailable."),
        compensation_unit: nullable_enum(%w[hourly daily weekly biweekly semimonthly monthly annual salary per_mile semiweekly variable]).merge(description: "Unit or period associated with compensation_amount."),
        paystubs: { type: :array, minItems: 1, items: ref("CePaystub"), description: "Only payments dated within the enclosing month and review period. Grouped by pay_date, even when the work period falls in another month. Undated paychecks and paychecks outside the review period are omitted." }
      }).merge(description: "Only published, successfully synchronized Argyle or Pinwheel accounts are included. Each employer appears once per month with a paycheck in the review period; employers without dated paychecks in that period have no entry. Payroll money values are in cents, and nullable provider fields remain null. Hours are reported on each paystub as hours_paid; there is no calculated employment-level hours field. A failed payroll fetch fails transmission so the job can retry rather than sending a partial report."),
      CeEducationActivity: {
        description: "Only published education activities are included: self-attested credits, verified NSC enrollment, or verified enrollment with self-attested credits. Fully self-attested education appears under each reported month. NSC term entries appear under each applicable reporting month, including eligible summer carryover. A month can contain multiple schools or terms.",
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
      CeSelfAttestedEducationActivity: activity(%w[school_name hours enrollment_status term education_type], self_attested.merge(contact).merge(education_term).merge(
        type: { type: :string, enum: %w[education] },
        data_source: { type: :string, enum: %w[self_attested] },
        school_name: { type: :string, description: "Name of the school reported by the applicant." },
        hours: { type: :number, minimum: 0, description: "Academic credit hours for the term; zero when optional credits are not supplied." },
        enrollment_status: { type: :string, enum: EducationActivity::SELF_ATTESTED_ENROLLMENT_STATUSES, description: "Self-attested enrollment status." }
      )).merge(description: "School details, term dates, enrollment status, and optional academic credits reported by the applicant, including address and contact fields. Manual terms appear in each reporting month covered by their dates."),
      CeVerifiedEducationActivity: activity(%w[school_name enrollment_status term education_type], education_term.merge(
        data_source: { type: :string, enum: %w[verified], description: "NSC-verified enrollment." }
      )).merge(description: "NSC-verified enrollment and original term details. NSC does not provide academic credit hours, so credit_hours is null."),
      CeVerifiedEnrollmentOnlyEducationActivity: activity(%w[school_name hours enrollment_status term education_type], self_attested.merge(contact).merge(education_term).merge(
        data_source: { type: :string, enum: %w[verified_enrollment_only], description: "NSC-verified enrollment, but whether the user was enrolled full-time, half-time, or less-than-half-time was not provided. The term credit_hours field is populated with self-attested values." },
        hours: { type: %w[number null], minimum: 0, description: "Self-attested academic credit hours for the term, matching credit_hours. Fractions and zero are preserved; null when not reported." }
      )).merge(description: "Partially self-attested education combines NSC enrollment and term details with applicant-reported academic credits, retaining self-attested address and contact fields. Every term entry uses verified_enrollment_only, including terms with half-time or greater enrollment."),
      CeEducationTerm: object(%w[start_month end_month], {
        start_month: month.merge(description: "Start month of the original enrollment term in YYYY-MM format."),
        end_month: month.merge(description: "End month of the original enrollment term in YYYY-MM format.")
      }).merge(description: "Original enrollment term dates, retained in each applicable reporting month, including summer carryover."),
      CePaystub: object(%w[pay_date pay_gross], {
        pay_date: { type: :string, format: :date, description: "Date of payment, used to assign the paycheck to its reporting month." },
        pay_period_start: nullable_string.merge(format: :date, description: "Start of the work period covered by the paycheck; may fall outside the payment's reporting month."),
        pay_period_end: nullable_string.merge(format: :date, description: "End of the work period covered by the paycheck; may fall outside the payment's reporting month."),
        pay_gross: cents.merge(description: "Gross pay in cents. Missing gross pay uses the income report's zero fallback."),
        pay_gross_ytd: cents(nullable: true).merge(description: "Year-to-date gross pay in cents; null when unavailable."),
        pay_net: cents(nullable: true).merge(description: "Net pay in cents; null when unavailable."),
        hours_paid: { type: %w[number null], description: "Hours paid, including overtime." },
        deductions: { type: :array, items: ref("CePaystubDeduction"), description: "Itemized deductions from this paycheck, with amounts in cents." },
        gross_pay_list: { type: :array, items: ref("CeGrossPayComponent"), description: "Itemized components of gross pay, with amounts in cents." }
      }),
      CePaystubDeduction: object(%w[category tax amount], {
        category: nullable_string.merge(description: "Deduction category reported by the payroll provider."),
        tax: { type: :string, enum: %w[pre_tax post_tax unknown], description: "Whether the deduction is taken before or after tax, or unknown." },
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

  def self.education_type
    nullable_enum(EducationActivity::EDUCATION_TYPES).merge(
      description: "Original education type selected by the applicant, retained when NSC verification falls back to self-attestation. Null for older records without a saved selection.",
      example: "college_or_university"
    )
  end

  def self.nullable_enum(values)
    nullable_string.merge(enum: [ *values, nil ])
  end

  def self.cents(nullable: false)
    { type: nullable ? %w[integer null] : :integer, description: "Amount in cents (12345 represents $123.45)." }
  end
end
