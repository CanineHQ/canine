# == Schema Information
#
# Table name: add_ons
#
#  id                :bigint           not null, primary key
#  chart_type        :string           not null
#  chart_url         :string
#  managed_namespace :boolean          default(TRUE)
#  metadata          :jsonb
#  name              :string           not null
#  namespace         :string           not null
#  status            :integer          default("installing"), not null
#  values            :jsonb
#  version           :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  cluster_id        :bigint           not null
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
class AddOn < ApplicationRecord
  include Loggable
  include TeamAccessible
  include Namespaced
  include Favoriteable
  include AccountUniqueName
  belongs_to :cluster

  def self.ransackable_attributes(auth_object = nil)
    %w[name chart_url]
  end

  has_one :account, through: :cluster

  enum :status, {
    installing: 0,
    installed: 1,
    uninstalling: 2,
    uninstalled: 3,
    failed: 4,
    updating: 5
  }

  validates :name, presence: true, format: { with: /\A[a-z0-9-]+\z/, message: "must be lowercase, numbers, and hyphens only" }
  validates :chart_url, presence: true, format: { with: %r{\A[^/]+/[^/]+\z}, message: "must be in format 'repository/chart'" }
  validates :version, presence: true
  validates :repository_url, presence: true
  after_update_commit do
    broadcast_replace_later_to [ self, :install_stage ], target: dom_id(self, :install_stage), partial: "add_ons/install_stage", locals: { add_on: self }
  end

  def update_install_stage!(stage)
    self.metadata['install_stage'] = stage
    save
  end

  def install_stage
    metadata['install_stage'] || 0
  end

  def chart_definition
    charts = K8::Helm::Client::CHARTS["helm"]["charts"]
    charts.find { |chart| chart["chart_url"] == chart_url } || {}
  end

  def repository_name
    chart_url&.split('/')&.first
  end

  protected

  def validate_keys(required_keys)
    missing_keys = required_keys - metadata.keys

    if missing_keys.any?
      errors.add(:metadata, "is missing required keys: #{missing_keys.join(', ')}")
    end
  end
end
