require "sidekiq/web"

Rails.application.routes.draw do
  if Rails.env.development?
    mount Sidekiq::Web => "/sidekiq"
  end
  scope "(:locale)", locale: /#{I18n.available_locales.join("|")}/ do
    # Your application routes go here
    root "pages#welcome"

    # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
    get "providers/search" => "providers#search"
    get "providers/confirm" => "providers#confirm"
    resources :providers
    # Defines the root path route ("/")
    # root "articles#index"
  end
end
