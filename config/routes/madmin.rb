# Below are the routes for madmin
namespace :madmin do
  namespace :action_text do
    resources :encrypted_rich_texts
  end
  namespace :action_text do
    resources :rich_texts
  end
  resources :announcements
  resources :services
  resources :users
  namespace :active_storage do
    resources :blobs
  end
  namespace :active_storage do
    resources :attachments
  end
  namespace :active_storage do
    resources :variant_records
  end
  namespace :noticed do
    resources :events
  end
  namespace :noticed do
    resources :notifications
  end
  root to: "dashboard#show"
end
