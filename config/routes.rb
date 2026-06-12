Rails.application.routes.draw do
  devise_for :users, controllers: { registrations: "users/registrations" }

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :admin do
    root to: "dashboard#index"

    resources :blog_posts
    resources :driver_performances, only: %i[index show]
    resources :support_conversations, only: %i[index show] do
      member do
        patch :close
        patch :reopen
      end
      resources :messages, only: %i[create], controller: "support_messages"
    end
    resources :wallet_payouts, only: %i[index] do
      member do
        patch :approve
        patch :payout
      end
    end

    resources :quotations do
      patch :transition, on: :member
      resources :quotation_items, path: :items, only: %i[create update destroy]
      resources :quotation_notes, path: :notes, only: %i[create update destroy]
      resources :quotation_payments, path: :payments, only: %i[create update destroy]
      resources :quotation_documents, path: :documents, only: %i[create update destroy]
      resources :driver_offers, only: %i[index] do
        patch :select, on: :member
      end
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
    resources :jobs, only: [] do
      resources :offers, only: %i[create update]
    end
    resources :availabilities
    resource :wallet, only: :show
  end

  resources :quotations, only: %i[index show new create] do
    patch :accept, on: :member
    patch :reject, on: :member
    patch :request_changes, on: :member
    post :deposit_checkout, to: "quotation_deposits#create", on: :member
    get :deposit_success, to: "quotation_deposits#success", on: :member
    get :deposit_cancel, to: "quotation_deposits#cancel", on: :member
  end

  resources :blog_posts, path: "blog", only: %i[index show]

  resources :conversations, only: %i[index show create] do
    resources :messages, only: %i[create]
  end

  resources :notifications, only: :index do
    patch :read, on: :member
    patch :read_all, on: :collection
  end
  resource :web_push_subscription, only: %i[create destroy]
  get "web_push/config", to: "web_push_subscriptions#configuration", as: :web_push_config

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

  get "services", to: "pages#services", as: :services
  get "services/home-removals", to: "pages#home_removals", as: :home_removals
  get "services/office-removals", to: "pages#office_removals", as: :office_removals
  get "services/packing-services", to: "pages#packing_services", as: :packing_services
  get "services/storage-solutions", to: "pages#storage_solutions", as: :storage_solutions
  get "how-it-works", to: "pages#how_it_works", as: :how_it_works
  get "about", to: "pages#about", as: :about
  get "reviews", to: "pages#reviews", as: :reviews
  get "contact", to: "pages#contact", as: :contact

  get "dashboard", to: "pages#dashboard", as: :dashboard
  get "jobs/:token", to: "public_jobs#show", as: :public_job
  root to: "pages#landing"
end
