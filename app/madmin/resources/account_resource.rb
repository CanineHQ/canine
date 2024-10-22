class AccountResource < Madmin::Resource
  # Associations
  attribute :owner
  attribute :users
  attribute :providers
  attribute :clusters
  attribute :projects
  attribute :services
  attribute :add_ons

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
