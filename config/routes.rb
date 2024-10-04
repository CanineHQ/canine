require "sidekiq/web"

Rails.application.routes.draw do
  draw :madmin
  namespace :inbound_webhooks do
    resources :github, controller: :github, only: [ :create ]
  end
  get "/privacy", to: "static#privacy"
  get "/terms", to: "static#terms"


  authenticated :user do
    root to: "projects#index", as: :user_root
    # Alternate route to use if logged in users should still see public root
    # get "/dashboard", to: "dashboard#show", as: :user_root
  end
  resources :add_ons do
    member do
      get :logs, to: "add_ons#logs"
    end
  end
  resources :projects, except: [ :show ] do
    get "/:project_id/deployments", to: "projects/deployments#index", as: :root
    resources :services, only: %i[index new create destroy update], module: :projects
    resources :metrics, only: [ :index ], module: :projects
    resources :project_add_ons, only: %i[create destroy], module: :projects
    resources :environment_variables, only: %i[index create], module: :projects
    resources :deployments, only: %i[index show], module: :projects do
      collection do
        post :deploy
      end
      member do
        post :redeploy
      end
    end
  end
  resources :clusters do
    member do
      get :download_kubeconfig
    end
    resource :metrics, only: [ :show ], module: :clusters
    member do
      post :test_connection
      post :restart
    end
  end
authenticate :user, lambda { |u| u.admin? } do
  mount Sidekiq::Web => "/sidekiq"

  namespace :madmin do
    resources :impersonates do
      post :impersonate, on: :member
      post :stop_impersonating, on: :collection
    end
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

  # Public marketing homepage
  root to: "static#index"
end
