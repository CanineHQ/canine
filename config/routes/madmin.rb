# Below are the routes for madmin
namespace :madmin do
  resources :add_ons
  resources :builds
  resources :clusters
  namespace :active_storage do
    resources :variant_records
  end
  namespace :active_storage do
    resources :attachments
  end
  resources :providers
  resources :cron_schedules
  resources :deployments
  resources :domains
  resources :environment_variables
  resources :inbound_webooks
  resources :log_outputs
  resources :announcements
  resources :metrics
  resources :projects
  resources :project_add_ons
  resources :services
  namespace :active_storage do
    resources :blobs
  end
  namespace :noticed do
    resources :events
  end
  resources :users
  namespace :noticed do
    resources :notifications
  end
  root to: "dashboard#show"
end
