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
  pending "add some examples to (or delete) #{__FILE__}"
end
