require 'rails_helper'

RSpec.describe MoneyHelper, type: :helper do
  describe '#format_hours' do
    it "rounds to the nearest tenth" do
      expect(helper.format_hours(57.3611)).to eq(57.4)
      expect(helper.format_hours(57.3411)).to eq(57.3)
    end

    it "ignores non numbers" do
      expect(helper.format_hours("hours")).to eq("hours")
      expect(helper.format_hours("30h")).to eq("30h")
    end
  end
end
