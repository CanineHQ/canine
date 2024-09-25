json.extract! project, :id, :name, :repository_url, :branch, :cluster_id, :subfolder, :created_at, :updated_at
json.url project_url(project, format: :json)
