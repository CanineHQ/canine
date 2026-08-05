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
class EmailPreference < ApplicationRecord
  belongs_to :user
end
