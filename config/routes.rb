require "sidekiq/web"

Rails.application.routes.draw do
  if Rails.env.development?
    mount Sidekiq::Web => "/sidekiq"
  end
  scope "(:locale)", locale: /#{I18n.available_locales.join("|")}/ do
    # Your application routes go here
    root "pages#home"

    # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

    scope '/cbv', as: :cbv_flow do
      get '/entry' => 'cbv_flows#entry'
      get '/employer_search' => 'cbv_flows#employer_search'
      get '/argyle_link' => 'cbv_flows#argyle_link'
      post '/summary' => 'cbv_flows#summary'
      get '/summary' => 'cbv_flows#summary'

      # Utility route to clear your session; useful during development
      get '/reset' => 'cbv_flows#reset'
    end
  end
end
