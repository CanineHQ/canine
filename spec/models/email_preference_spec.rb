# == Schema Information
#
# Table name: email_preferences
#
#  id             :bigint           not null, primary key
#  service_health :boolean          default(TRUE), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  user_id        :bigint           not null
#
# Indexes
#
#  index_email_preferences_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
require 'rails_helper'

RSpec.describe EmailPreference, type: :model do
  pending "add some examples to (or delete) #{__FILE__}"
end
