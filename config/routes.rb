Rails.application.routes.draw do
  authenticate :user, ->(user) { user.admin? } do
    mount Avo::Engine, at: Avo.configuration.root_path
    Avo::Engine.routes.draw do
      # This route is not protected, secure it with authentication if needed.
      get "dashboard", to: "tools#dashboard", as: :dashboard
      post "login_as/:id", to: "tools#login_as", as: :login_as
    end
  end
  resources :accounts, only: [ :create ] do
    resources :account_users, only: %i[create index destroy], module: :accounts
    member do
      get :switch
    end
  end
  namespace :inbound_webhooks do
    resources :github, controller: :github, only: [ :create ]
    resources :gitlab, controller: :gitlab, only: [ :create ]
  end
  get "/privacy", to: "static#privacy"
  get "/terms", to: "static#terms"

  authenticated :user do
    root to: "projects#index", as: :user_root
    # Alternate route to use if logged in users should still see public root
    # get "/dashboard", to: "dashboard#show", as: :user_root
  end
  get "/integrations/github/repositories", to: "integrations/github/repositories#index"
  resources :add_ons do
    collection do
      get :search
      get :default_values
    end
    member do
      post :restart
    end
    resource :metrics, only: [ :show ], module: :add_ons
    resources :endpoints, only: %i[edit update], module: :add_ons
    resources :processes, only: %i[index show], module: :add_ons
  end

  resources :providers, only: %i[index new create destroy]
  resources :projects do
    member do
      post :restart
    end
    collection do
      get "/:project_id/deployments", to: "projects/deployments#index", as: :root
    end
    resources :project_forks, only: %i[index edit create], module: :projects
    resources :volumes, only: %i[index new create destroy], module: :projects
    resources :processes, only: %i[index show create destroy], module: :projects
    resources :services, only: %i[index new create destroy update], module: :projects do
      resources :jobs, only: %i[create], module: :services
      resources :domains, only: %i[create destroy], module: :services do
        collection do
          post :check_dns
        end
      end
    end
    resources :metrics, only: [ :index ], module: :projects
    resources :project_add_ons, only: %i[create destroy], module: :projects
    resources :environment_variables, only: %i[index create destroy], module: :projects
    resources :deployments, only: %i[index show], module: :projects do
      collection do
        post :deploy
      end
      member do
        post :redeploy
        patch :kill
      end
    end
  end
  resources :clusters do
    member do
      post :transfer_ownership
      get :download_kubeconfig
      get :download_yaml
      get :logs
    end
    resource :metrics, only: [ :show ], module: :clusters
    resource :build_cloud, only: [ :show, :edit, :update, :create, :destroy ], module: :clusters
    member do
      post :test_connection
      post :retry_install
    end
    collection do
      post :check_k3s_ip_address
    end
  end

  authenticate :user, lambda { |u| u.admin? } do
    namespace :admin do
      mount Flipper::UI.app(Flipper) => '/flipper', as: :flipper
      mount GoodJob::Engine => "/good_job"
    end
  end

  resources :notifications, only: [ :index ]
  resources :announcements, only: [ :index ]
  devise_for :users, controllers: { omniauth_callbacks: "users/omniauth_callbacks", registrations: "users/registrations", sessions: "users/sessions" }
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "async_render" => "async_renderer#async_render"

  get "/calculator", to: "static#calculator"
  # Public marketing homepage
  if Rails.application.config.local_mode
    get "/github_token", to: "local/pages#github_token"
    put "/github_token", to: "local/pages#update_github_token"
    namespace :local do
      resources :onboarding, only: [ :index ]
      resource :portainer, only: [ :show, :update ] do
        collection do
          get :github_oauth
        end
      end
    end
    root to: "projects#index"
  else
    root to: "static#index"
  end
end
