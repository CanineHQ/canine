# == Schema Information
#
# Table name: add_ons
#
#  id                      :bigint           not null, primary key
#  chart_type              :string           not null
#  chart_url               :string
#  managed_namespace       :boolean          default(TRUE)
#  metadata                :jsonb
#  name                    :string           not null
#  namespace               :string           not null
#  repository_url          :string           not null
#  status                  :integer          default("installing"), not null
#  values                  :jsonb
#  version                 :string           not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  artifact_hub_package_id :string
#  cluster_id              :bigint           not null
#
# Indexes
#
#  index_add_ons_on_cluster_id           (cluster_id)
#  index_add_ons_on_cluster_id_and_name  (cluster_id,name) UNIQUE
#  index_add_ons_on_name                 (name)
#
# Foreign Keys
#
#  fk_rails_...  (cluster_id => clusters.id)
#
FactoryBot.define do
  factory :add_on do
    cluster
    chart_url { 'bitnami/redis' }
    chart_type { "helm_chart" }
    repository_url { "https://charts.bitnami.com/bitnami" }
    version { "1.0.0" }
    sequence(:name) { |n| "example-addon-#{n}" }
    sequence(:namespace) { |n| "example-addon-#{n}" }
    managed_namespace { true }
    status { :installing }
    values { {} }
    metadata { { "package_details" => { "repository" => { "name" => "bitnami", "url" => "https://bitnami.com/charts" } } } }
  end
end
