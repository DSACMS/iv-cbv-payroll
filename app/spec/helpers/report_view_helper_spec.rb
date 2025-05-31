require 'rails_helper'

RSpec.describe ReportViewHelper, type: :helper do
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

  describe '#translate_aggregator_value' do
    around do |ex|
      I18n.with_locale(locale, &ex)
    end

    context 'when locale is :es' do
      let(:locale) { :es }

      it 'returns the translated value if translation exists' do
        I18n.backend.store_translations(:es, {
          aggregator_strings: {
            namespace: {
              existing_value: 'Translated Value'
            }
          }
        })

        result = helper.translate_aggregator_value('namespace', 'existing_value')
        expect(result).to eq('Translated Value')
      end

      it 'raises an error in development or test if translation is missing' do
        # Use a key that doesn't exist
        expect {
          helper.translate_aggregator_value('namespace', 'missing_value')
        }.to raise_error('Missing aggregator translation for namespace.missing_value')
      end

      it 'logs a warning and returns the original value in production if translation is missing' do
        # Simulate production environment
        allow(Rails.env).to receive(:development?).and_return(false)
        allow(Rails.env).to receive(:test?).and_return(false)

        # Expect a warning to be logged
        expect(Rails.logger).to receive(:warn).with('Unknown aggregator value for namespace: missing_value')

        result = helper.translate_aggregator_value('namespace', 'missing_value')
        expect(result).to eq('missing_value')
      end
    end

    context 'when locale is not :es' do
      let(:locale) { :en }

      before do
        I18n.backend.store_translations(:en, {
          aggregator_strings: {
            namespace: {
              some_value: 'Translated Value'
            }
          }
        })
      end

      it 'returns the English value' do
        result = helper.translate_aggregator_value('namespace', 'some_value')
        expect(result).to eq('Translated Value')
      end

      context 'when the value is nil' do
        it 'returns nil' do
          result = helper.translate_aggregator_value('namespace', nil)
          expect(result).to be_nil
        end
      end

      context 'when there is no English value given' do
        it 'returns the original value regardless of translations' do
          result = helper.translate_aggregator_value('namespace', 'any_value')
          expect(result).to eq('any_value')
        end
      end
    end
  end
  describe '#format_parsed_date' do
    around do |ex|
      I18n.with_locale(locale, &ex)
    end

    context 'when locale is :en' do
      let(:locale) { :en }

      it 'formats January 1st correctly' do
        date = Date.new(2023, 1, 1)
        expect(helper.format_parsed_date(date)).to eq('January 1, 2023')
      end

      it 'formats February 28th correctly' do
        date = Date.new(2023, 2, 28)
        expect(helper.format_parsed_date(date)).to eq('February 28, 2023')
      end

      it 'formats December 31st correctly' do
        date = Date.new(2023, 12, 31)
        expect(helper.format_parsed_date(date)).to eq('December 31, 2023')
      end
    end

    context 'when locale is :es' do
      let(:locale) { :es }

      it 'formats January 1st correctly' do
        date = Date.new(2023, 1, 1)
        expect(helper.format_parsed_date(date)).to eq('1 de enero de 2023')
      end

      it 'formats February 28th correctly' do
        date = Date.new(2023, 2, 28)
        expect(helper.format_parsed_date(date)).to eq('28 de febrero de 2023')
      end

      it 'formats December 31st correctly' do
        date = Date.new(2023, 12, 31)
        expect(helper.format_parsed_date(date)).to eq('31 de diciembre de 2023')
      end
    end
  end

  describe '#format_date' do
    around do |ex|
      I18n.with_locale(locale, &ex)
    end

    context 'when locale is :en' do
      let(:locale) { :en }

      it 'formats January 1st correctly' do
        date_string = "2023-01-01"
        expect(helper.format_date(date_string)).to eq('January 1, 2023')

        date_string = "2023-1-1"
        expect(helper.format_date(date_string)).to eq('January 1, 2023')

        date = Date.new(2023, 1, 1)
        expect(helper.format_date(date)).to eq('January 1, 2023')
      end

      it 'formats February 28th correctly' do
        date_string = "2023-02-28"
        expect(helper.format_date(date_string)).to eq('February 28, 2023')

        date = Date.new(2023, 2, 28)
        expect(helper.format_date(date)).to eq('February 28, 2023')
      end

      it 'formats December 31st correctly' do
        date_string = "2023-12-31"
        expect(helper.format_date(date_string)).to eq('December 31, 2023')

        date = Date.new(2023, 12, 31)
        expect(helper.format_date(date)).to eq('December 31, 2023')
      end

      it 'formats a date with "%b" format as August correctly' do
        date = Date.new(2023, 8, 7) # A Tuesday
        format = "%b"

        expect(helper.format_date(date, format: format)).to match(/Aug/)
      end

      it 'formats a date with "%A" format as Wednesday correctly' do
        date = Date.new(2023, 11, 8) # A Wednesday
        format = "%A"

        expect(helper.format_date(date, format: format)).to match(/Wednesday/)
      end
    end

    context 'when locale is :es' do
      let(:locale) { :es }

      it 'formats January 1st correctly' do
        date_string = "2023-1-1"
        expect(helper.format_date(date_string)).to eq('1 de enero de 2023')

        date = Date.new(2023, 1, 1)
        expect(helper.format_date(date)).to eq('1 de enero de 2023')
      end

      it 'formats February 28th correctly' do
        date_string = "2023-02-28"
        expect(helper.format_date(date_string)).to eq('28 de febrero de 2023')

        date = Date.new(2023, 2, 28)
        expect(helper.format_date(date)).to eq('28 de febrero de 2023')
      end

      it 'formats December 31st correctly' do
        date_string = "2023-12-31"
        expect(helper.format_date(date_string)).to eq('31 de diciembre de 2023')

        date = Date.new(2023, 12, 31)
        expect(helper.format_date(date)).to eq('31 de diciembre de 2023')
      end

      it 'formats a date with "%b" format as August correctly' do
        date = Date.new(2023, 8, 7) # A Tuesday
        format = "%b"

        expect(helper.format_date(date, format: format)).to match(/ago/)
      end

      it 'formats a date with "%A" format as Wednesday correctly' do
        date = Date.new(2023, 11, 8) # A Wednesday
        format = { format: "%A" }

        expect(helper.format_date(date, format: format)).to match(/miércoles/)
      end
    end
  end

  describe "#report_data_range" do
    let(:report) { build(:argyle_report) }
    let(:fetched_days) { 90 }

    before do
      allow(report)
        .to receive(:fetched_days)
        .and_return(fetched_days)
    end

    subject { helper.report_data_range(report) }

    it "renders when 90 days of data were fetched" do
      expect(subject).to eq(I18n.t("shared.report_data_range.ninety_days"))
    end

    context "when 182 days of data were fetched" do
      let(:fetched_days) { 182 }

      it "returns the string for six months" do
        expect(subject).to eq(I18n.t("shared.report_data_range.six_months"))
      end
    end

    context "when an invalid number of days were fetched" do
      let(:fetched_days) { 0 }

      it "raises an error" do
        expect { subject }.to raise_error(/Missing i18n key/)
      end
    end
  end
end
