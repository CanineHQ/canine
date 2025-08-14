# == Schema Information
#
# Table name: build_clouds
#
#  id                    :bigint           not null, primary key
#  driver_version        :string
#  error_message         :text
#  installation_metadata :jsonb
#  installed_at          :datetime
#  namespace             :string           default("canine-k8s-builder"), not null
#  status                :integer          default("pending"), not null
#  webhook_url           :string
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  cluster_id            :bigint           not null
#
# Indexes
#
#  index_build_clouds_on_cluster_id  (cluster_id)
#
# Foreign Keys
#
#  fk_rails_...  (cluster_id => clusters.id)
#
require 'rails_helper'

RSpec.describe BuildCloud, type: :model do
  pending "add some examples to (or delete) #{__FILE__}"
end
