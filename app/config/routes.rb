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
    # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

    scope "/cbv", as: :cbv_flow, module: :cbv do
      resource :entry, only: %i[show]
      resource :employer_search, only: %i[show]
      resource :synchronizations, only: %i[show]
      resource :summary, only: %i[show update], format: %i[html pdf]
      resource :missing_results, only: %i[show]
      resource :success, only: %i[show]
      resource :agreement, only: %i[show create]
      resource :add_job, only: %i[show create]
      resource :payment_details, only: %i[show update]
      resource :expired_invitation, only: %i[show]

      # Utility route to clear your session; useful during development
      resource :reset, only: %i[show]
    end

    scope "/:site_id", module: :caseworker, constraints: { site_id: Regexp.union(Rails.application.config.sites.site_ids) } do
      get "/sso", to: redirect("/%{site_id}") # Temporary: Remove once people get used to going to /:site_id as the login destination.
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
    scope :pinwheel do
      post "/tokens" => "pinwheel#create_token"
    end
  end
end
