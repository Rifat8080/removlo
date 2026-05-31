Rails.application.routes.draw do
  devise_for :users

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :admin do
    resources :quotations do
      patch :transition, on: :member
      resources :quotation_items, path: :items, only: %i[create update destroy]
      resources :quotation_notes, path: :notes, only: %i[create update destroy]
      resources :quotation_payments, path: :payments, only: %i[create update destroy]
      resources :quotation_documents, path: :documents, only: %i[create update destroy]
    end

    resources :users
  end

  namespace :driver do
    resources :jobs, only: %i[index show]
  end

  resources :quotations, only: %i[index show new create] do
    patch :accept, on: :member
    patch :reject, on: :member
    patch :request_changes, on: :member
  end

  resources :notifications, only: :index do
    patch :read, on: :member
    patch :read_all, on: :collection
  end
  resource :web_push_subscription, only: %i[create destroy]
  get "web_push/config", to: "web_push_subscriptions#config", as: :web_push_config

  get "dashboard", to: "pages#dashboard", as: :dashboard
  root to: "pages#landing"
end
