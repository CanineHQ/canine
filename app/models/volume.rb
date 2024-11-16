# == Schema Information
#
# Table name: volumes
#
#  id          :bigint           not null, primary key
#  access_mode :integer          default("read_write_once")
#  mount_path  :string           default("/volumes/data"), not null
#  name        :string           not null
#  size        :string           default("10Gi"), not null
#  status      :integer          default("pending")
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  project_id  :bigint           not null
#
# Indexes
#
#  index_volumes_on_project_id                 (project_id)
#  index_volumes_on_project_id_and_mount_path  (project_id,mount_path) UNIQUE
#  index_volumes_on_project_id_and_name        (project_id,name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (project_id => projects.id)
#
class Volume < ApplicationRecord
  belongs_to :project
  validates :name, presence: true,
                   format: { with: /\A[a-z0-9_-]+\z/, message: "must be lowercase, numbers, hyphens, and underscores only" },
                   uniqueness: { scope: :project_id }

  validates :mount_path, presence: true, uniqueness: { scope: :project_id }
  validate :mount_path_must_be_absolute

  enum :status, {
    pending: 0,
    deployed: 1,
    failed: 2
  }

  enum :access_mode, {
    read_write_once: 0,
  }

  private

  def mount_path_must_be_absolute
    return if mount_path.blank?
    errors.add(:mount_path, "must be an absolute path") unless mount_path.start_with?('/')
  end
end
