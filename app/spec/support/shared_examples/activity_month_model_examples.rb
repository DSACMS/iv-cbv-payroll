RSpec.shared_examples "an activity month model" do |parent_factory:, month_factory:, parent_association:|
  describe "associations" do
    it "belongs to its parent activity" do
      month_record = create(month_factory)
      expect(month_record.public_send(parent_association)).to be_present
    end
  end

  describe "validations" do
    let(:parent_activity) { create(parent_factory) }

    it "is valid with a month and non-negative hours" do
      month_record = build(month_factory, parent_association => parent_activity, hours: 10)
      expect(month_record).to be_valid
    end

    it "is valid with zero hours" do
      month_record = build(month_factory, parent_association => parent_activity, hours: 0)
      expect(month_record).to be_valid
    end

    it "is invalid without a month" do
      month_record = build(month_factory, parent_association => parent_activity, month: nil)
      expect(month_record).not_to be_valid
      expect(month_record.errors[:month]).to be_present
    end

    it "is invalid with negative hours" do
      month_record = build(month_factory, parent_association => parent_activity, hours: -1)
      expect(month_record).not_to be_valid
      expect(month_record.errors[:hours]).to be_present
    end

    it "is invalid with non-integer hours" do
      month_record = build(month_factory, parent_association => parent_activity, hours: 2.5)
      expect(month_record).not_to be_valid
      expect(month_record.errors[:hours]).to be_present
    end
  end

  describe "dependent destroy" do
    it "is destroyed when the parent activity is destroyed" do
      parent_activity = create(parent_factory)
      create(month_factory, parent_association => parent_activity, hours: 10)

      expect { parent_activity.destroy }.to change(described_class, :count).by(-1)
    end
  end
end
