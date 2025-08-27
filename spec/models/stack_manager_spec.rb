# == Schema Information
#
# Table name: stack_managers
#
#  id                 :bigint           not null, primary key
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
require 'rails_helper'

RSpec.describe StackManager, type: :model do
  describe 'validations' do
    it { is_expected.to validate_presence_of(:account) }
    it { is_expected.to validate_presence_of(:provider_url) }
    it { is_expected.to validate_presence_of(:stack_manager_type) }
  end

  describe 'associations' do
    it { is_expected.to belong_to(:account) }
  end

  describe 'enums' do
    it { is_expected.to define_enum_for(:stack_manager_type).with_values(portainer: 0) }
  end
end
