require "rails_helper"

RSpec.describe UnattachedUploadCleanupJob do
  let(:activity_flow) { create(:activity_flow) }
  let(:checksum) { Digest::MD5.base64digest("%PDF-1.4") }

  def upload_blob(created_at:)
    signed_id = PresignedUploadService.new.call([
      { filename: "verification.pdf", content_type: "application/pdf", byte_size: 8, checksum: checksum }
    ]).first[:signed_id]

    ActiveStorage::Blob.find_signed!(signed_id).tap { |blob| blob.update!(created_at: created_at) }
  end

  it "deletes blobs that were never attached to an activity" do
    abandoned = upload_blob(created_at: 25.hours.ago)

    described_class.perform_now

    expect(ActiveStorage::Blob.exists?(abandoned.id)).to be(false)
  end

  it "leaves recent blobs alone, since the user may still be on the page" do
    in_progress = upload_blob(created_at: 1.hour.ago)

    described_class.perform_now

    expect(ActiveStorage::Blob.exists?(in_progress.id)).to be(true)
  end

  it "leaves attached blobs alone however old they are" do
    attached = upload_blob(created_at: 25.hours.ago)
    create(:volunteering_activity, activity_flow: activity_flow).document_uploads.attach(attached)

    described_class.perform_now

    expect(ActiveStorage::Blob.exists?(attached.id)).to be(true)
  end

  it "does not try to delete the object from the quarantine bucket" do
    upload_blob(created_at: 25.hours.ago)

    expect(ActiveStorage::Blob.services.fetch(PresignedUploadService::SERVICE_NAME)).not_to receive(:delete)

    expect { described_class.perform_now }.not_to have_enqueued_job(ActiveStorage::PurgeJob)
  end
end
