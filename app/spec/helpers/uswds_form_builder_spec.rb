require 'rails_helper'

RSpec.describe UswdsFormBuilder do
  class TestModel
    include ActiveModel::Model

    attr_accessor :first_name, :start_date
  end

  let(:template) { ActionView::Base.empty }
  let(:object) { TestModel.new }
  let(:builder) { UswdsFormBuilder.new(:object, object, template, {}) }

  describe '#text_field' do
    let(:result) { builder.text_field(:first_name, label: 'Name') }

    it 'outputs a text input' do
      expect(result).to have_element(:input, type: 'text', class: 'usa-input', name: 'object[first_name]')
      expect(result).not_to have_css('.usa-form-group--error')
      expect(result).not_to have_css('.usa-error-message')
    end

    it 'outputs a label' do
      expect(result).to have_element(:label, class: 'usa-label', for: 'object_first_name')
    end

    context 'with id option' do
      let(:result) { builder.text_field(:first_name, id: 'custom-id') }

      it 'outputs a label associated with the input with the custom id' do
        expect(result).to have_element(:input, id: 'custom-id')
        expect(result).to have_element(:label, for: 'custom-id')
      end
    end

    context 'with label option' do
      let(:result) { builder.text_field(:first_name, label: 'Custom label') }

      it 'outputs a label' do
        expect(result).to have_element(:label, text: 'Custom label', class: 'usa-label')
      end
    end

    context 'with hint' do
      let(:result) { builder.text_field(:first_name, hint: 'Enter your name') }

      it 'outputs a hint' do
        expect(result).to have_element(:div, text: 'Enter your name', class: 'usa-hint')
      end

      it 'adds aria-describedby to the input' do
        expect(result).to have_element(:input, aria_describedby: 'first_name_hint')
      end
    end

    context 'with errors' do
      let(:result) { builder.text_field(:first_name) }

      before do
        object.errors.add(:first_name, 'is invalid')
      end

      it 'outputs an error message' do
        expect(result).to have_element(:div, class: 'usa-form-group--error')
        expect(result).to have_element(:span, text: 'is invalid', class: 'usa-error-message')
      end
    end

    context 'with width' do
      let(:result) { builder.text_field(:first_name, width: 'md') }

      it 'adds a width class' do
        expect(result).to have_element(:input, class: 'usa-input usa-input--md')
      end
    end

    context 'with optional set to true' do
      let(:result) { builder.text_field(:first_name, label: 'Name', optional: true) }

      it 'outputs an optional label' do
        expect(result).to have_element(:label, text: 'Name (optional)')
      end
    end

    context 'with custom class' do
      let(:result) { builder.text_field(:first_name, class: 'custom-class') }

      it 'adds the class to the input' do
        expect(result).to have_element(:input, class: 'custom-class usa-input')
      end
    end

    context 'with label_class' do
      let(:result) { builder.text_field(:first_name, label_class: 'custom-label-class') }

      it 'adds the class to the label' do
        expect(result).to have_element(:label, class: 'usa-label custom-label-class')
      end
    end
  end

  describe '#hint' do
    let(:result) { builder.hint('Enter your name') }

    it 'outputs a hint' do
      expect(result).to have_element(:div, text: 'Enter your name', class: 'usa-hint')
    end
  end

  describe '#date_picker' do
    let(:result) { builder.date_picker(:start_date) }
    let(:object) { TestModel.new(start_date: Date.new(2024, 1, 31)) }

    it 'wraps the input with a date picker class' do
      expect(result).to have_element(:div, class: 'usa-date-picker usa-form-group')
    end

    it 'includes example format in the hint' do
      expect(result).to have_element(:p, text: I18n.t('us_form_with.date_picker_format'))
    end

    it 'adds USWDS attributes for showing the current value' do
      expect(result).to have_element(:input, value: '01/31/2024')
      expect(result).to have_element(:div, class: 'usa-date-picker', "data-default-value": '2024-01-31')
    end

    context 'no existing date value' do
      let(:object) { TestModel.new(start_date: nil) }

      it 'does not set a value' do
        expect(result).to have_element(:input, value: nil)
        expect(result).to have_element(:div, class: 'usa-date-picker', "data-default-value": nil)
      end
    end
  end

  describe '#fieldset' do
    let(:result) { builder.fieldset('Legend') { 'Fieldset content' } }

    it 'outputs a fieldset' do
      expect(result).to have_element(:fieldset, class: 'usa-fieldset')
    end

    it 'outputs a legend' do
      expect(result).to have_element(:legend, text: 'Legend', class: 'usa-legend')
    end

    it 'outputs the content within the block' do
      expect(result).to have_text('Fieldset content')
    end

    context 'with large_legend set to true' do
      let(:result) { builder.fieldset('Legend', large_legend: true) { 'Fieldset content' } }

      it 'outputs a large legend' do
        expect(result).to have_element(:legend, class: 'usa-legend usa-legend--large')
      end
    end
  end

  describe '#select' do
    let(:result) { builder.select(:first_name, [ 'Option 1', 'Option 2' ]) }

    it 'outputs a select field' do
      expect(result).to have_element(:select, class: 'usa-select', name: 'object[first_name]')
    end

    context 'with label' do
      let(:result) { builder.select(:first_name, [ 'Option 1', 'Option 2' ], label: 'Custom label') }

      it 'outputs a label' do
        expect(result).to have_element(:label, text: 'Custom label', class: 'usa-label')
      end
    end
  end

  describe '#submit' do
    let (:result) { builder.submit() }

    it 'outputs a submit button' do
      expect(result).to have_element(:input, type: 'submit', class: 'usa-button')
    end

    context 'with big set to true' do
      let (:result) { builder.submit(nil, { big: true }) }

      it 'outputs a big submit button' do
        expect(result).to have_element(:input, type: 'submit', class: 'usa-button--big')
      end
    end
  end

  describe '#check_box' do
    let(:result) { builder.check_box(:first_name) }

    it 'outputs a check box' do
      expect(result).to have_element(:div, class: 'usa-checkbox')
      expect(result).to have_element(:input, type: 'checkbox', class: 'usa-checkbox__input', name: 'object[first_name]')
    end

    context 'with hint' do
      let(:result) { builder.check_box(:first_name, hint: 'Check this box') }

      it 'outputs a hint' do
        expect(result).to have_element(:span, text: 'Check this box', class: 'usa-checkbox__label-description')
      end
    end
  end

  describe '#radio_button' do
    let(:result) { builder.radio_button(:first_name, 'yes') }

    it 'outputs a radio button' do
      expect(result).to have_element(:div, class: 'usa-radio')
      expect(result).to have_element(:input, type: 'radio', class: 'usa-radio__input', name: 'object[first_name]', value: 'yes')
    end

    context 'with hint' do
      let(:result) { builder.radio_button(:first_name, 'yes', hint: 'Select yes') }

      it 'outputs a hint' do
        expect(result).to have_element(:span, text: 'Select yes', class: 'usa-radio__label-description')
      end
    end
  end

  describe '#yes_no' do
    let(:result) { builder.yes_no(:first_name, legend: 'Custom legend') }

    it 'outputs radio buttons for yes and no' do
      expect(result).to have_element(:input, type: 'radio', class: 'usa-radio__input', value: 'true', name: 'object[first_name]')
      expect(result).to have_element(:input, type: 'radio', class: 'usa-radio__input', value: 'false', name: 'object[first_name]')

      expect(result).to have_element(:label, text: 'Yes', class: 'usa-radio__label')
      expect(result).to have_element(:label, text: 'No', class: 'usa-radio__label')

      expect(result).to have_element(:legend, text: 'Custom legend', class: 'usa-legend')
    end

    context 'with custom labels' do
      let(:result) { builder.yes_no(:first_name,
        yes_options: { label: "Yes, I've taken leave before" },
        no_options: { label: "No, I haven't taken leave before" }
      ) }

      it 'outputs radio buttons with custom labels' do
        expect(result).to have_element(:label, text: "Yes, I've taken leave before")
        expect(result).to have_element(:label, text: "No, I haven't taken leave before")
      end
    end
  end

  describe '#memorable_date' do
    let(:result) { builder.memorable_date(:start_date, legend: 'Start date', hint: 'Please enter the start date') }

    it 'outputs a fieldset with a legend' do
      expect(result).to have_element(:fieldset, class: 'usa-fieldset')
      expect(result).to have_element(:legend, text: 'Start date', class: 'usa-legend')
    end

    it 'outputs a memorable date component' do
      expect(result).to have_element(:div, class: 'usa-memorable-date')
    end

    it 'outputs a select for the month' do
      expect(result).to have_element(:select, name: 'object[start_date][month]')
    end

    it 'outputs a text input for the day' do
      expect(result).to have_element(:input, type: 'number', name: 'object[start_date][day]')
    end

    it 'outputs a text input for the year' do
      expect(result).to have_element(:input, type: 'number', name: 'object[start_date][year]')
    end

    context 'with hint' do
      it 'outputs a hint' do
        expect(result).to have_element(:div, text: 'Please enter the start date', class: 'usa-hint')
      end
    end

    context 'with errors' do
      before do
        object.errors.add(:start_date, 'is invalid')
      end

      it 'outputs an error message' do
        expect(result).to have_element(:div, class: 'usa-form-group--error')
        expect(result).to have_element(:span, text: 'is invalid', class: 'usa-error-message')
      end
    end

    context 'with existing date value' do
      let(:object) { TestModel.new(start_date: Date.new(2024, 2, 28)) }

      it 'sets the month value' do
        expect(result).to have_element(:option, value: '2', selected: 'selected')
      end

      it 'sets the day value' do
        expect(result).to have_element(:input, value: '28', name: 'object[start_date][day]')
      end

      it 'sets the year value' do
        expect(result).to have_element(:input, value: '2024', name: 'object[start_date][year]')
      end
    end
  end

  describe '#button_with_icon' do
    let(:result) { builder.button_with_icon('Save') }

    it 'outputs a button with default classes' do
      expect(result).to have_element(:button, type: 'button', class: 'usa-button')
      expect(result).to have_text('Save')
    end

    context 'with default value when no text provided' do
      let(:result) { builder.button_with_icon }

      it 'outputs a button with default text' do
        expect(result).to have_element(:button, type: 'button', class: 'usa-button')
        expect(result).to have_text('Button')
      end
    end

    context 'with options hash as first parameter' do
      let(:result) { builder.button_with_icon(icon: 'save_alt', type: 'submit') }

      it 'treats the hash as options and uses default button text' do
        expect(result).to have_element(:button, type: 'submit', class: 'usa-button')
        expect(result).to have_text('Button')
        expect(result).to have_element(:svg, class: 'usa-icon')
        expect(result).to have_element(:use, href: /.svg#save_alt/)
      end
    end

    context 'with icon' do
      let(:result) { builder.button_with_icon('Copy', icon: 'content_copy') }

      it 'outputs a button with icon' do
        expect(result).to have_element(:button, class: 'usa-button')
        expect(result).to have_element(:svg, class: 'usa-icon')
        expect(result).to have_element(:use, href: /.svg#content_copy/)
      end
    end

    context 'with variant' do
      let(:result) { builder.button_with_icon('Delete', variant: 'secondary') }

      it 'adds variant class' do
        expect(result).to have_element(:button, class: 'usa-button usa-button--secondary')
      end
    end

    context 'with multiple variants' do
      let(:result) { builder.button_with_icon('Delete', variant: %w[secondary outline]) }

      it 'adds multiple variant classes' do
        expect(result).to have_element(:button, class: 'usa-button usa-button--secondary usa-button--outline')
      end
    end

    context 'with custom type' do
      let(:result) { builder.button_with_icon('Submit', type: 'submit') }

      it 'sets the button type' do
        expect(result).to have_element(:button, type: 'submit')
      end
    end

    context 'with custom class' do
      let(:result) { builder.button_with_icon('Save', class: 'custom-class') }

      it 'adds custom class to button' do
        expect(result).to have_element(:button, class: 'usa-button custom-class')
      end
    end

    context 'with icon and variant' do
      let(:result) { builder.button_with_icon('Save', icon: 'save_alt', variant: 'big') }

      it 'outputs button with both icon and variant styling' do
        expect(result).to have_element(:button, class: 'usa-button usa-button--big')
        expect(result).to have_element(:svg, class: 'usa-icon')
        expect(result).to have_element(:use, href: /.svg#save_alt/)
      end
    end
  end
end
