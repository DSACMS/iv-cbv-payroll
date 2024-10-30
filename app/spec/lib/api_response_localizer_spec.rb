require 'rails_helper'

RSpec.describe ApiResponseLocalizer do
  before do
    I18n.backend.store_translations(:es, {
      api_responses: {
        test_service: {
          'hello' => 'Hola',
          'world' => 'Mundo',
          'test'  => 'Prueba'
        }
      }
    })
  end

  let(:dummy_service_class) do
    Class.new do
      include ApiResponseLocalizer

      def some_method
        {
          'message' => 'Hello',
          'data' => %w[World Test]
        }
      end

      localize_methods :some_method

      private

      def i18n_scope
        'api_responses.test_service'
      end
    end
  end

  let(:service) { dummy_service_class.new }

  context 'when locale is Spanish' do
    before { I18n.locale = :es }
    after { I18n.locale = I18n.default_locale }

    it 'localizes the response' do
      response = service.some_method
      expect(response).to eq({
        'message' => 'Hola',
        'data' => %w[Mundo Prueba]
      })
    end
  end

  context 'when locale is English' do
    before { I18n.locale = :en }
    after { I18n.locale = I18n.default_locale }

    it 'returns the original response' do
      response = service.some_method
      expect(response).to eq({
       'message' => 'Hello',
        'data' => %w[World Test]
       })
    end
  end
end
