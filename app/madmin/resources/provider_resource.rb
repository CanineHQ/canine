class ProviderResource < Madmin::Resource
  # Attributes
  attribute :id, form: false
  attribute :provider
  attribute :uid
  attribute :access_token
  attribute :access_token_secret
  attribute :refresh_token
  attribute :expires_at
  attribute :auth
  attribute :created_at, form: false
  attribute :updated_at, form: false

  # Associations
  attribute :user

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
