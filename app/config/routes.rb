require "sidekiq/web"

Rails.application.routes.draw do
  if Rails.env.development?
    mount Sidekiq::Web => "/sidekiq"
  end
  scope "(:locale)", locale: /#{I18n.available_locales.join("|")}/ do
    # Your application routes go here
    root "pages#home"

    get "/health", to: "health_check#ok"
    get "/health/test_rendering", to: "health_check#test_rendering"
    # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

    scope "/cbv", as: :cbv_flow do
      get "/entry" => "cbv_flows#entry"
      get "/employer_search" => "cbv_flows#employer_search"
      patch "/summary" => "cbv_flows#summary"
      get "/summary" => "cbv_flows#summary"
      patch "/share" => "cbv_flows#share"
      get "/share" => "cbv_flows#share"

      # Utility route to clear your session; useful during development
      get "/reset" => "cbv_flows#reset"

      resources :cbv_flow_invitations, as: :invitations, path: :invitations, only: %i[new create]
    end
  end

  namespace :webhooks do
    namespace :pinwheel do
      resources :events, only: :create
    end
  end

  namespace :api do
    scope :pinwheel do
      post "/tokens" => "pinwheel#create_token"
    end
  end
end
