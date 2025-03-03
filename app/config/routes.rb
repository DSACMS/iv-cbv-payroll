require "sidekiq/web"

Rails.application.routes.draw do
  devise_for :users,
    controllers: {
      sessions:           "users/sessions",
      omniauth_callbacks: "users/omniauth_callbacks"
    }

  devise_scope :user do
    delete "sign_out", to: "devise/sessions#destroy", as: :destroy_user_session
  end

  if Rails.env.development?
    mount Sidekiq::Web => "/sidekiq"
  end

  scope "(:locale)", locale: /#{I18n.available_locales.join("|")}/, format: "html"  do
    # Your application routes go here
    root "pages#home"

    get "/health", to: "health_check#ok"
    get "/health/test_rendering", to: "health_check#test_rendering"
    get "/help", to: "help#index", as: :help
    get "/help/:topic", to: "help#show", as: :help_topic
    get "/maintenance", to: "maintenance#show"
    # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

    scope "/cbv", as: :cbv_flow, module: :cbv do
      resource :entry, only: %i[show create]
      resource :employer_search, only: %i[show]
      resource :synchronizations, only: %i[show update]
      resource :synchronization_failures, only: %i[show]
      resource :summary, only: %i[show update], format: %i[html pdf]
      resource :missing_results, only: %i[show]
      resource :success, only: %i[show]
      resource :add_job, only: %i[show create]
      resource :payment_details, only: %i[show update]
      resource :expired_invitation, only: %i[show]
      # Utility route to clear your session; useful during development
      resource :reset, only: %i[show]

      post "session/refresh", to: "session#refresh", as: :session_refresh
      delete "session", to: "session#destroy", as: :session_destroy
    end

    scope "/:client_agency_id", module: :caseworker, constraints: { client_agency_id: Regexp.union(Rails.application.config.client_agencies.client_agency_ids) } do
      get "/sso", to: redirect("/%{client_agency_id}") # Temporary: Remove once people get used to going to /:client_agency_id as the login destination.
      root to: "entries#index", as: :new_user_session

      resource :dashboard, only: %i[show], as: :caseworker_dashboard
      resources :cbv_flow_invitations, only: %i[new create], as: :invitations, path: :invitations
    end
  end

  namespace :webhooks do
    namespace :pinwheel do
      resources :events, only: :create
    end
  end

  namespace :api do
    scope :v1 do
      post "/invitations", to: "invitations#create"
    end

    scope :pinwheel do
      post "/tokens" => "pinwheel#create_token"
    end

    scope :events do
      post :user_action, to: "user_events#user_action"
    end
  end

  match "/404", to: "pages#error_404", via: :all
  match "/500", to: "pages#error_500", via: :all
end
