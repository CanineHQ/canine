class ProjectResource < Madmin::Resource
  # Attributes
  attribute :id, form: false
  attribute :name
  attribute :repository_url
  attribute :branch
  attribute :autodeploy
  attribute :dockerfile_path
  attribute :docker_build_context_directory
  attribute :docker_command
  attribute :predeploy_command
  attribute :status
  attribute :created_at, form: false
  attribute :updated_at, form: false

  # Associations
  attribute :cluster
  attribute :account
  attribute :services
  attribute :environment_variables
  attribute :builds
  attribute :deployments
  attribute :domains

  # Uncomment this to customize the display name of records in the admin area.
  # def self.display_name(record)
  #   record.name
  # end

  # Uncomment this to customize the default sort column and direction.
  # def self.default_sort_column
  #   "created_at"
  # end
  #
  # def self.default_sort_direction
  #   "desc"
  # end
end
