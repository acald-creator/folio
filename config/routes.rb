Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    get "board", to: "board#show"
    resource :profile, only: [ :show, :update ], controller: "profile"
    post "careers/lookup", to: "careers#lookup"
    post "careers/import", to: "careers#import"
    resources :clients, only: [ :create ]
    resources :commissions, only: [ :create, :update, :destroy ] do
      post :move, on: :member
      resources :assets, only: [ :create ]
    end
    resources :assets, only: [ :destroy ]
  end

  root "home#index"
end
