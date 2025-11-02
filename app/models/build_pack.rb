# == Schema Information
#
# Table name: build_packs
#
#  id                     :bigint           not null, primary key
#  details                :jsonb
#  name                   :string
#  namespace              :string
#  reference_type         :string           not null
#  uri                    :text
#  version                :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  build_configuration_id :bigint           not null
#
# Indexes
#
#  index_build_packs_on_build_configuration_id      (build_configuration_id)
#  index_build_packs_on_config_type_namespace_name  (build_configuration_id,reference_type,namespace,name)
#  index_build_packs_on_config_uri                  (build_configuration_id,uri)
#
# Foreign Keys
#
#  fk_rails_...  (build_configuration_id => build_configurations.id)
#
class BuildPack < ApplicationRecord
  VERIFIED_NAMESPACES = %w[io.buildpacks paketo-buildpacks heroku tanzu-buildpacks].freeze

  belongs_to :build_configuration

  enum :reference_type, {
    registry: 0,
    git: 1,
    url: 2,
  }

  validates :reference_type, presence: true
  validates :namespace, presence: true, if: :registry?
  validates :name, presence: true, if: :registry?
  validates :uri, presence: true, unless: :registry?

  # Helper method to get full buildpack reference for pack CLI
  def reference
    case reference_type.to_sym
    when :registry
      if version.present?
        "#{namespace}/#{name}:#{version}"
      else
        "#{namespace}/#{name}"
      end
    else
      uri
    end
  end

  # Synthetic property to check if buildpack is from a verified namespace
  def verified?
    registry? && VERIFIED_NAMESPACES.include?(namespace)
  end

  # Display name for UI
  def display_name
    if registry?
      "#{namespace}/#{name}"
    elsif git? && uri.present?
      # Extract repo name from git URL
      uri.split('/').last.to_s.gsub('.git', '')
    else
      uri
    end
  end
end
