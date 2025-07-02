require "rails_helper"

RSpec.describe AgencyNameMatchingService do
  let(:first_name_list) do
    [ "Cassian Andor" ]
  end
  let(:second_name_list) do
    [ "Varian Skye" ]
  end

  describe "#match_results" do
    subject do
      described_class
        .new(first_name_list, second_name_list)
        .match_results
    end

    it "returns the correct results" do
      expect(subject).to eq(
        exact_match_count: 0,
        close_match_count: 0,
        approximate_match_count: 0,
        none_match_count: 1
      )
    end

    context "when there are exact name matches" do
      let(:second_name_list) { [ "Cassian Andor" ] }

      it "returns them as exact matches" do
        expect(subject).to eq(
          exact_match_count: 1,
          close_match_count: 0,
          approximate_match_count: 0,
          none_match_count: 0
        )
      end
    end

    context "when there are exact name matches differing by capitalization" do
      let(:second_name_list) { [ "cassian andor" ] }

      it "returns them as exact matches" do
        expect(subject).to eq(
          exact_match_count: 1,
          close_match_count: 0,
          approximate_match_count: 0,
          none_match_count: 0
        )
      end
    end

    context "when there are exact name matches based on whitespace" do
      let(:second_name_list) { [ "Cassian And Or" ] }

      it "returns them as exact matches" do
        expect(subject).to eq(
          exact_match_count: 1,
          close_match_count: 0,
          approximate_match_count: 0,
          none_match_count: 0
        )
      end
    end

    context "when there are hyphenated surnames" do
      let(:second_name_list) { [ "Cassian Andor-Erso" ] }

      it "returns them as exact matches" do
        expect(subject).to eq(
          exact_match_count: 1,
          close_match_count: 0,
          approximate_match_count: 0,
          none_match_count: 0
        )
      end
    end

    context "when there are hyphenated surnames in the first list" do
      let(:first_name_list) { [ "Varian Andor-Skye" ] }

      it "returns them as exact matches" do
        expect(subject).to eq(
          exact_match_count: 1,
          close_match_count: 0,
          approximate_match_count: 0,
          none_match_count: 0
        )
      end
    end


    context "when there are middle initials" do
      let(:second_name_list) { [ "Cassian E Andor" ] }

      it "returns them as exact matches" do
        expect(subject).to eq(
          exact_match_count: 1,
          close_match_count: 0,
          approximate_match_count: 0,
          none_match_count: 0
        )
      end
    end

    context "when there are multiple matching name parts" do
      let(:first_name_list) do
        [ "Cassian Andor Skye" ]
      end
      let(:second_name_list) do
        [ "Maarva Andor Skye" ]
      end

      it "returns them as close matches" do
        expect(subject).to eq(
          exact_match_count: 0,
          close_match_count: 1,
          approximate_match_count: 0,
          none_match_count: 0
        )
      end
    end

    context "when there is only one matching name part" do
      let(:second_name_list) do
        [ "Maarva Andor" ]
      end

      it "returns them as approximate matches" do
        expect(subject).to eq(
          exact_match_count: 0,
          close_match_count: 0,
          approximate_match_count: 1,
          none_match_count: 0
        )
      end
    end

    context "with a complex set of name comparisons" do
      let(:first_name_list) do
        [
          "Cassian Andor",       # exact match to "Cassian Caleen-Andor"
          "Kleya R. Marki",      # exact match to "Kleya Marki"
          "Senator Bail Organa", # close match to "Senator Leia Organa"
          "Galen Erso",          # approx match to "jyn erso"
          "Vel Kaz-Sartha",      # approx match to "Cinta Kaz"
          "Saw Gerrera"          # no match
        ]
      end
      let(:second_name_list) do
        [
          "Cassian Caleen-Andor",
          "Kleya Marki",
          "Senator Leia Organa",
          "jyn erso",
          "Cinta Kaz"
        ]
      end

      it "returns the number of matches as specified" do
        expect(subject).to eq(
          exact_match_count: 2,
          close_match_count: 1,
          approximate_match_count: 2,
          none_match_count: 1
        )
      end
    end
  end
end
