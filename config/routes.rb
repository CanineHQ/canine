Rails.application.routes.draw do
  # API routes
  namespace :api do
    namespace :v1 do
      resource :me, only: :show, controller: "me"
      resources :projects, only: %i[index show] do
        member do
          post :deploy
          post :restart
        end
        resources :processes, only: %i[index show create destroy], module: :projects
      end
      resources :builds, only: %i[index show] do
        member do
          patch :kill
        end
      end
      resources :clusters, only: %i[index] do
        member do
          get :download_kubeconfig
        end
      end
      resources :add_ons, only: %i[index show] do
        member do
          post :restart
        end
      end
    end
  end

  use_doorkeeper

  # RFC 7591: Dynamic Client Registration Protocol
  post "/oauth/register", to: "oauth_client_registration#create", as: :oauth_register

  # RFC 9728: Protected Resource Metadata (MCP server as protected resource)
  get "/.well-known/oauth-protected-resource",       to: "oauth_authorization_server_metadata#protected_resource"
  get "/.well-known/oauth-protected-resource/mcp",   to: "oauth_authorization_server_metadata#protected_resource"

  # RFC 8414: Authorization Server Metadata (OAuth server endpoints)
  get "/.well-known/oauth-authorization-server",     to: "oauth_authorization_server_metadata#authorization_server"
  get "/.well-known/oauth-authorization-server/mcp", to: "oauth_authorization_server_metadata#authorization_server"

  post "/mcp", to: "mcp#handle"
  get  "/mcp", to: "mcp#handle"

  # Account-specific URL-based routes
  devise_scope :user do
    get '/accounts/:slug/sign_in', to: 'users/sessions#account_login', as: :account_sign_in
    post '/accounts/:slug/sign_in', to: 'users/sessions#account_create'
  end

  # OIDC authentication routes
  get '/accounts/:slug/auth/oidc', to: 'accounts/oidc#authorize', as: :oidc_auth
  get '/accounts/:slug/auth/oidc/callback', to: 'accounts/oidc#callback', as: :oidc_callback

  # SAML authentication routes
  get '/accounts/:slug/auth/saml', to: 'accounts/saml#authorize', as: :saml_auth
  post '/accounts/:slug/auth/saml/callback', to: 'accounts/saml#callback', as: :saml_callback
  get '/accounts/:slug/auth/saml/metadata', to: 'accounts/saml#metadata', as: :saml_metadata

  authenticate :user, ->(user) { user.admin? } do
    mount Avo::Engine, at: Avo.configuration.root_path
    Avo::Engine.routes.draw do
      # This route is not protected, secure it with authentication if needed.
      get "dashboard", to: "tools#dashboard", as: :dashboard
      resource :impersonation, only: [ :destroy ] do
        post :create, on: :collection, action: :create
        get :create, on: :collection, action: :create, as: :start
      end
      resource :password_reset, only: [ :create ]
      resource :promote_to_admin, only: [ :create, :destroy ]
    end
  end
  resources :accounts, only: [ :create ] do
    collection do
      resources :account_users, only: %i[create index update destroy], module: :accounts
      resource :sso_provider, only: %i[show new create edit update destroy], module: :accounts do
        post :test_connection
      end
      resources :teams, module: :accounts do
        resources :team_memberships, only: %i[create destroy], module: :teams
        resources :team_resources, only: %i[create destroy], module: :teams
        resources :team_members_search, only: %i[index], module: :teams
      end
    end
    member do
      get :switch
    end
  end

  resource :stack_manager, only: %i[show new create edit update destroy], controller: 'accounts/stack_managers' do
    collection do
      post :verify_url
      post :check_reachable
      post :verify_connectivity
      post :sync_clusters
      post :sync_registries
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

  resources :favorites, only: [] do
    collection do
      post :toggle
    end
  end
  get "/integrations/github/repositories", to: "integrations/github/repositories#index"
  get "/search", to: "search#index"
  resources :build_packs, only: [] do
    collection do
      get :search
      get :details
    end
  end
  resources :add_ons do
    collection do
      get :search
      get :metadata
    end
    member do
      post :restart
      get :download_values
    end
    resource :metrics, only: [ :show ], module: :add_ons
    resources :endpoints, only: %i[edit update], module: :add_ons
    resources :processes, only: %i[index show], module: :add_ons
  end

  resources :providers, only: %i[index new create destroy]
  resources :api_tokens, only: %i[index new create destroy]
  resource :portainer_token, only: %i[update destroy], controller: 'providers/portainer_tokens'
  resources :projects do
    member do
      post :restart
    end
    collection do
      get "/:project_id/deployments", to: "projects/deployments#index", as: :root
    end
    resources :project_forks, only: %i[index edit create], module: :projects
    resources :volumes, only: %i[index new create destroy], module: :projects
    resources :notifiers, only: %i[index new create edit update destroy], module: :projects
    resources :processes, only: %i[index show create destroy], module: :projects
    resources :services, only: %i[index new create destroy update show], module: :projects do
      resource :resource_constraint, only: %i[show new create update destroy], module: :services
      resources :jobs, only: %i[show create destroy], module: :services
      resources :domains, only: %i[create destroy], module: :services do
        collection do
          post :check_dns
        end
      end
    end
    resources :metrics, only: [ :index ], module: :projects
    resources :project_add_ons, only: %i[create destroy], module: :projects
    resources :environment_variables, only: %i[index show create destroy], module: :projects do
      collection do
        get :download
      end
    end
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

  resource :password_change, only: [ :show, :update ], controller: "password_change"

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "async_render" => "async_renderer#async_render"

  get "/api-docs", to: "static#docs"
  get "/swagger", to: "static#swagger"

  get "/calculator", to: "static#calculator"
  # Public marketing homepage
  if Rails.application.config.local_mode
    namespace :local do
      resources :authentication do
        member do
          post :login
        end
      end
      resources :onboarding, only: [ :index, :create ] do
        collection do
          get :account_select
        end
      end
    end
    if Rails.application.config.onboarding_methods.any?
      root to: "local/onboarding#index"
    else
      root to: "local/onboarding#account_select"
    end
  else
    root to: "static#index"
  end
end
