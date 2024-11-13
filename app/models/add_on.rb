# == Schema Information
#
# Table name: add_ons
#
#  id         :bigint           not null, primary key
#  chart_type :string           not null
#  metadata   :jsonb
#  name       :string           not null
#  status     :integer          default("installing"), not null
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
  DISPLAY_NAME = {
    'redis': "Redis",
    'postgresql': "PostgreSQL"
  }.freeze
  include Loggable
  belongs_to :cluster
  has_one :account, through: :cluster
  enum :status, { installing: 0, installed: 1, uninstalling: 2, uninstalled: 3, failed: 4 }
  validates :chart_type, presence: true
  validate :chart_type_exists
  validates :name, presence: true, format: { with: /\A[a-z0-9_-]+\z/, message: "must be lowercase, numbers, hyphens, and underscores only" }
  validates_uniqueness_of :name, scope: :cluster_id

  def helm_chart_url
    chart_definition["repository"]
  end

  protected

  def chart_definition
    charts = K8::Helm::Client::CHARTS["helm"]["charts"]
    charts.find { |chart| chart["name"] == chart_type }
  end

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
