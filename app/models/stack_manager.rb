# == Schema Information
#
# Table name: stack_managers
#
#  id                 :bigint           not null, primary key
#  access_token       :string
#  provider_url       :string           not null
#  stack_manager_type :integer          default("portainer"), not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  account_id         :bigint           not null
#
# Indexes
#
#  index_stack_managers_on_account_id  (account_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class StackManager < ApplicationRecord
  belongs_to :account

  enum :stack_manager_type, {
    portainer: 0
  }

  validates_presence_of :account, :provider_url, :stack_manager_type
  validates_uniqueness_of :account

  before_validation :strip_trailing_slash_from_provider_url

  def requires_reauthentication?
    access_token.blank?
  end

  def stack
    if portainer?
      @_stack ||= Portainer::Stack.new(self)
    end
  end

  private

  def strip_trailing_slash_from_provider_url
    return if provider_url.blank?

    uri = URI.parse(provider_url)
    uri.path = ""
    uri.query = nil
    uri.fragment = nil
    self.provider_url = uri.to_s
  rescue URI::InvalidURIError
    # Leave provider_url unchanged if it's invalid
  end
end
