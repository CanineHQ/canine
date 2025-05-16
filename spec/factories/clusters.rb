# == Schema Information
#
# Table name: clusters
#
#  id           :bigint           not null, primary key
#  cluster_type :integer          default("k8s")
#  kubeconfig   :jsonb            not null
#  name         :string           not null
#  status       :integer          default("initializing"), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  account_id   :bigint           not null
#
# Indexes
#
#  index_clusters_on_account_id_and_name  (account_id,name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
FactoryBot.define do
  factory :cluster do
    account
    sequence(:name) { |n| "test-cluster-#{n}" }
    kubeconfig { { "apiVersion" => "v1", "clusters" => [] }.to_json }
    status { :initializing }
    cluster_type { :k8s }
  end
end
