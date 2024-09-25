# == Schema Information
#
# Table name: domains
#
#  id          :bigint           not null, primary key
#  domain_name :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  service_id  :bigint           not null
#
# Indexes
#
#  index_domains_on_service_id  (service_id)
#
# Foreign Keys
#
#  fk_rails_...  (service_id => services.id)
#
class Domain < ApplicationRecord
end
