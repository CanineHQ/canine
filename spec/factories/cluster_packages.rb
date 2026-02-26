# == Schema Information
#
# Table name: cluster_packages
#
#  id           :bigint           not null, primary key
#  config       :jsonb
#  installed_at :datetime
#  name         :string           not null
#  status       :integer          default("pending"), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  cluster_id   :bigint           not null
#
# Indexes
#
#  index_cluster_packages_on_cluster_id           (cluster_id)
#  index_cluster_packages_on_cluster_id_and_name  (cluster_id,name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (cluster_id => clusters.id)
#
FactoryBot.define do
  factory :cluster_package do
    cluster
    name { "nginx-ingress" }
    status { :pending }
    config { {} }
  end
end
