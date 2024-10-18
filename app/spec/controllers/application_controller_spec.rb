require 'rails_helper'

class DummyController < ApplicationController
  def test_action
    switch_locale do
      render plain: I18n.locale.to_s
    end
  end
end

RSpec.describe ApplicationController, type: :controller do
  controller(DummyController) do
    def test_action
      switch_locale do
        render plain: I18n.locale.to_s
      end
    end
  end

  describe '#switch_locale' do
    before do
      I18n.default_locale = :en
      routes.draw do
        get 'test_action', to: 'dummy#test_action'
      end
    end

    it 'uses the locale from params if it is valid' do
      get :test_action, params: { locale: 'es' }
      expect(response.body).to eq('es')
    end

    it 'uses the default locale if the param locale is not valid' do
      get :test_action, params: { locale: 'de' }
      expect(response.body).to eq('en')
    end

    it 'uses the default locale if no locale param is provided' do
      get :test_action
      expect(response.body).to eq('en')
    end
  end
end
