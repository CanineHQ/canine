class UserResource < Madmin::Resource
  # Attributes
  attribute :id, form: false
  attribute :email
  attribute :encrypted_password
  attribute :reset_password_token
  attribute :reset_password_sent_at
  attribute :remember_created_at
  attribute :confirmation_token
  attribute :confirmed_at
  attribute :confirmation_sent_at
  attribute :unconfirmed_email
  attribute :first_name
  attribute :last_name
  attribute :time_zone
  attribute :accepted_terms_at
  attribute :accepted_privacy_at
  attribute :announcements_read_at
  attribute :admin
  attribute :created_at, form: false
  attribute :updated_at, form: false
  attribute :invitation_token
  attribute :invitation_created_at
  attribute :invitation_sent_at
  attribute :invitation_accepted_at
  attribute :invitation_limit
  attribute :invited_by_type
  attribute :invited_by_id
  attribute :invitations_count, form: false
  attribute :preferred_language
  attribute :otp_required_for_login
  attribute :otp_secret
  attribute :last_otp_timestep
  attribute :otp_backup_codes
  attribute :preferences
  attribute :name
  attribute :avatar, index: false

  # Associations
  attribute :notifications
  attribute :notification_mentions
  attribute :providers

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
