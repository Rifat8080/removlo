Rails.application.routes.draw do
  devise_for :users

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :admin do
    resources :blog_posts

    resources :quotations do
      patch :transition, on: :member
      resources :quotation_items, path: :items, only: %i[create update destroy]
      resources :quotation_notes, path: :notes, only: %i[create update destroy]
      resources :quotation_payments, path: :payments, only: %i[create update destroy]
      resources :quotation_documents, path: :documents, only: %i[create update destroy]
    end

    resources :users

    namespace :accounting do
      root to: "dashboard#index"
      resources :categories, except: :show
      resources :transactions
      resources :customer_invoices, path: :invoices do
        get :pdf, on: :member
      end
      resources :payroll_runs do
        member do
          patch :finalize
          patch :mark_paid
        end
        resources :payslips, only: %i[new create edit update destroy] do
          get :pdf, on: :member
        end
      end
      get :reports, to: "reports#index"
    end

    namespace :shop do
      resources :product_categories, except: :show
      resources :products
      resources :material_orders, only: %i[index show update] do
        member do
          patch :transition
          get :pdf
        end
      end
    end
  end

  namespace :driver do
    resources :jobs, only: %i[index show]
  end

  resources :quotations, only: %i[index show new create] do
    patch :accept, on: :member
    patch :reject, on: :member
    patch :request_changes, on: :member
  end

  resources :blog_posts, path: "blog", only: %i[index show]

  resources :notifications, only: :index do
    patch :read, on: :member
    patch :read_all, on: :collection
  end
  resource :web_push_subscription, only: %i[create destroy]
  get "web_push/config", to: "web_push_subscriptions#config", as: :web_push_config

  resources :customer_invoices, path: "invoices", only: %i[index show] do
    get :pdf, on: :member
  end
  resources :payslips, only: %i[index show] do
    get :pdf, on: :member
  end

  scope module: :shop, path: "shop", as: :shop do
    resources :products, only: %i[index show], param: :slug
  end

  resource :cart, only: :show do
    post :add
  end
  patch "cart/items/:id", to: "carts#update", as: :cart_item
  delete "cart/items/:id", to: "carts#remove", as: :remove_cart_item

  get "checkout", to: "checkouts#show", as: :checkout
  post "checkout", to: "checkouts#create"
  get "checkout/success", to: "checkouts#success", as: :checkout_success
  get "checkout/cancel", to: "checkouts#cancel", as: :checkout_cancel

  resources :material_orders, only: %i[index show] do
    get :pdf, on: :member
  end

  post "stripe/webhook", to: "stripe_webhooks#create"

  get "dashboard", to: "pages#dashboard", as: :dashboard
  root to: "pages#landing"
end
