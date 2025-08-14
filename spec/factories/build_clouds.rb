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
FactoryBot.define do
  factory :build_cloud do
    cluster { nil }
    namespace { "MyString" }
    status { 1 }
    driver_version { "MyString" }
    webhook_url { "MyString" }
    installation_metadata { "" }
    installed_at { "2025-08-15 16:40:46" }
    error_message { "MyText" }
  end
end
