namespace :api do
  resources :pinwheel, only: [] do
    collection do
      post :tokens, action: :create_token
    end
  end

  resources :event_tracker, only: [] do
    collection do
      post :user_action
    end
  end
end 