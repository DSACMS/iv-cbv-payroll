Rails.application.routes.draw do
  devise_for :users

  scope "(:locale)", locale: /#{I18n.available_locales.join("|")}/, format: "html" do
    # Your application routes go here
    root "pages#home"

    get "/health", to: "health_check#ok"
    get "/health/test_queueing", to: "health_check#test_queueing"
    get "/health/test_rendering", to: "health_check#test_rendering"
    get "/help", to: "help#index", as: :help
    get "/help/:topic", to: "help#show", as: :help_topic
    get "/maintenance", to: "maintenance#show"
    # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

    # Feedback CTA
    get "/feedback", to: "feedbacks#show", as: :feedbacks

    # RFI (mail) origin tracking route for LA
    get "/start", to: "pages#home", defaults: { origin: "mail" }

    # Tokenized links
    get "/start/:token", to: "cbv/entries#show", as: :start_flow, token: /[^\/]+/

    scope "/cbv", as: :cbv_flow, module: :cbv do
      resource :entry, only: %i[show create]
      resource :employer_search, only: %i[show]
      resource :synchronizations, only: %i[show update]
      resource :synchronization_failures, only: %i[show]
      resource :summary, only: %i[show update]
      resource :submit, only: %i[show update], format: %i[html pdf]
      resource :missing_results, only: %i[show]
      resource :success, only: %i[show]
      resource :add_job, only: %i[show create]
      resource :other_job, only: %i[show update]
      resource :payment_details, only: %i[show update]
      resource :expired_invitation, only: %i[show]
      resource :applicant_information, only: %i[show update]

      # Generic link
      scope "links/:client_agency_id", constraints: { client_agency_id: Regexp.union(Rails.application.config.client_agencies.client_agency_ids) } do
        root to: "generic_links#show", as: :new
      end

      # Session management
      post "session/refresh", to: "sessions#refresh", as: :session_refresh
      get "session/end", to: "sessions#end", as: :session_end
      get "session/timeout", to: "sessions#timeout", as: :session_timeout
    end

    scope "/activities", as: :activities_flow, module: :activities do
      root to: "activities#index"
      resource :entry, only: %i[show], controller: "entries"
      resources :community_service, only: %i[new create edit update destroy], controller: "volunteering" do
        resources :document_uploads, only: %i[new create], controller: "/activities/document_uploads"
        resources :months, only: %i[edit update], controller: "volunteering/months"

        member do
          get :review
          patch :save_review
        end
      end
      resources :job_training, only: %i[new create edit update destroy], controller: "job_training" do
        resources :document_uploads, only: %i[new create], controller: "/activities/document_uploads"
      end
      resource :summary, only: %i[show], controller: "summary"
      resource :submit, only: %i[show update], controller: "submit", format: %i[html pdf]
      resource :success, only: %i[show], controller: "success"
      scope "/income", as: :income do
        resource :employer_search, only: %i[show], controller: "/cbv/employer_searches"
        resource :synchronizations, only: %i[show update], controller: "/cbv/synchronizations"
        resource :synchronization_failures, only: %i[show], controller: "/cbv/synchronization_failures"
        resource :payment_details, only: %i[show update], controller: "/cbv/payment_details"
      end

      resources :education, only: %i[new create show update edit destroy], controller: "education" do
        patch "sync", to: "education#sync", as: :sync
      end
      get "/education/error", to: "education#error", as: :education_error

      # Tokenized links
      get "start/:token", to: "entries#show", as: :start, token: /[^\/]+/

      # Generic links by agency
      scope "links/:client_agency_id", constraints: { client_agency_id: Regexp.union(Rails.application.config.client_agencies.client_agency_ids) } do
        root to: "entries#show", as: :new
      end
    end
  end

  namespace :webhooks do
    namespace :pinwheel do
      resources :events, only: :create
    end

    namespace :argyle do
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

    scope :argyle do
      post "/tokens" => "argyle#create"
    end

    scope :events do
      post :user_action, to: "user_events#user_action"
    end
  end

  mount MissionControl::Jobs::Engine, at: "/jobs"

  match "/404", to: "pages#error_404", via: :all
  match "/500", to: "pages#error_500", via: :all

  if Rails.application.config.is_internal_environment
    mount Lookbook::Engine, at: "/lookbook"
    get "/demo", to: "demo_launcher#show"
    post "/demo", to: "demo_launcher#create"
  end
end
