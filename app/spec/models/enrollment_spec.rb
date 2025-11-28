require 'rails_helper'

RSpec.describe Enrollment, type: :model do
  describe "#less_than_part_time?" do
    context "status is full time" do
      subject { create(:enrollment, status: :full_time) }

      it "is not less than part time" do
        expect(subject.less_than_part_time?).to be(false)
      end
    end
    context "status is part time" do
      subject { create(:enrollment, status: :part_time) }

      it "is not less than part time" do
        expect(subject.less_than_part_time?).to be(false)
      end
    end
    context "status is quarter time" do
      subject { create(:enrollment, status: :quarter_time) }

      it "is less than part time" do
        expect(subject.less_than_part_time?).to be(true)
      end
    end
  end

  describe "#current?" do
    context "semester started more than six months ago" do
      let(:semester_start) do
        Faker::Date.between(from: Date.today.prev_year,
                           to: Date.today.prev_month(7))
      end

      subject do
        create(:enrollment, semester_start: semester_start)
      end

      it "is not current" do
        expect(subject.current?).to be(false)
      end
    end
    context "semester started less than six months ago" do
      let(:semester_start) do
        Faker::Date.between(from: Date.today.prev_month(6),
                           to: Date.today)
      end

      subject do
        create(:enrollment, semester_start: semester_start)
      end

      it "is not current" do
        expect(subject.current?).to be(true)
      end
    end
    context "semester will start within six months" do
      let(:semester_start) do
        Faker::Date.between(from: Date.today,
                           to: Date.today.next_month(6))
      end

      subject do
        create(:enrollment, semester_start: semester_start)
      end

      it "is not current" do
        expect(subject.current?).to be(true)
      end
    end
    context "semester will start more than six months from now" do
      let(:semester_start) do
        Faker::Date.between(from: Date.today.next_month(7),
                           to: Date.today.next_year)
      end

      subject do
        create(:enrollment, semester_start: semester_start)
      end

      it "is not current" do
        expect(subject.current?).to be(false)
      end
    end
  end
end
