# == Schema Information
#
# Table name: add_ons
#
#  id         :bigint           not null, primary key
#  chart_type :string           not null
#  metadata   :jsonb
#  name       :string           not null
#  status     :integer          default("installing"), not null
#  values     :jsonb
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  cluster_id :bigint           not null
#
# Indexes
#
#  index_add_ons_on_cluster_id           (cluster_id)
#  index_add_ons_on_cluster_id_and_name  (cluster_id,name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (cluster_id => clusters.id)
#
class AddOn < ApplicationRecord
  include Loggable
  belongs_to :cluster
  has_one :account, through: :cluster
  enum :status, { installing: 0, installed: 1, uninstalling: 2, uninstalled: 3, failed: 4, updating: 5 }
  validates :chart_type, presence: true
  validate :chart_type_exists
  validates :name, presence: true, format: { with: /\A[a-z0-9-]+\z/, message: "must be lowercase, numbers, and hyphens only" }
  validate :name_is_unique_to_cluster, on: :create
  validate :has_package_details, if: :helm_chart?

  def name_is_unique_to_cluster
    if cluster.namespaces.include?(name)
      errors.add(:name, "must be unique to this cluster")
    end
  end

  def has_package_details
    if metadata['package_details'].blank?
      errors.add(:metadata, "is missing required keys: package_details")
    end
  end

  def helm_chart?
    chart_type == 'helm_chart'
  end

  def helm_chart_url
    chart_definition["repository"] || metadata["repository"]
  end

  def chart_definition
    charts = K8::Helm::Client::CHARTS["helm"]["charts"]
    charts.find { |chart| chart["name"] == chart_type }
  end

  protected

  def chart_type_exists
    if chart_definition.nil?
      errors.add(:chart_type, "does not exist")
    end
  end

  def validate_keys(required_keys)
    missing_keys = required_keys - metadata.keys

    if missing_keys.any?
      errors.add(:metadata, "is missing required keys: #{missing_keys.join(', ')}")
    end
  end
end
