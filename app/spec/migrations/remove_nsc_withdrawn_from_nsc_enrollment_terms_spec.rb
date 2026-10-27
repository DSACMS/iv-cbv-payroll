require "rails_helper"
require_relative "../../db/migrate/20261028000000_remove_nsc_withdrawn_from_nsc_enrollment_terms"

RSpec.describe RemoveNscWithdrawnFromNscEnrollmentTerms do
  let(:connection) { ActiveRecord::Base.connection }
  let!(:withdrawn_term) { create(:nsc_enrollment_term, enrollment_status: :unknown, school_certified_on: Date.new(2024, 7, 1)) }
  let!(:unknown_term) { create(:nsc_enrollment_term, enrollment_status: :unknown) }
  let!(:full_time_term) { create(:nsc_enrollment_term, enrollment_status: :full_time) }

  before do
    connection.add_column :nsc_enrollment_terms, :nsc_withdrawn, :boolean, default: false
    connection.execute("UPDATE nsc_enrollment_terms SET nsc_withdrawn = TRUE WHERE id = #{withdrawn_term.id}")
    described_class.new.suppress_messages { described_class.new.up }
    NscEnrollmentTerm.reset_column_information
  end

  after do
    NscEnrollmentTerm.reset_column_information
  end

  it "preserves withdrawals as grouped statuses before removing the legacy column" do
    expect(withdrawn_term.reload).to have_attributes(
      enrollment_status: "withdrawn", school_certified_on: Date.new(2024, 7, 1)
    )
    expect(connection.column_exists?(:nsc_enrollment_terms, :nsc_withdrawn)).to be(false)
  end

  it "preserves unflagged statuses" do
    expect(unknown_term.reload.enrollment_status).to eq("unknown")
    expect(full_time_term.reload.enrollment_status).to eq("full_time")
  end
end
