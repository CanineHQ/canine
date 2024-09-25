# == Schema Information
#
# Table name: announcements
#
#  id                :bigint           not null, primary key
#  announcement_type :string
#  description       :text
#  name              :string
#  published_at      :datetime
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
class Announcement < ApplicationRecord
end
