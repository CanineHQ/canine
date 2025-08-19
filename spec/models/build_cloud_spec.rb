# == Schema Information
#
# Table name: build_clouds
#
#  id                    :bigint           not null, primary key
#  cpu_limits            :bigint           default(2000)
#  cpu_requests          :bigint           default(500)
#  driver_version        :string
#  error_message         :text
#  installation_metadata :jsonb
#  installed_at          :datetime
#  memory_limits         :bigint           default(4294967296)
#  memory_requests       :bigint           default(536870912)
#  namespace             :string           default("canine-k8s-builder"), not null
#  replicas              :integer          default(2)
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
