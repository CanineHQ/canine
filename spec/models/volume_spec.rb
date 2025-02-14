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
require 'rails_helper'

RSpec.describe Volume, type: :model do
  let(:volume) { build(:volume) }
  describe 'validations' do
    it 'is invalid without an absolute mount_path' do
      volume.mount_path = 'relative/path'
      expect(volume).not_to be_valid
      expect(volume.errors[:mount_path]).to include("must be an absolute path")
    end

    it 'is valid with an absolute mount_path' do
      volume.mount_path = '/absolute/path'
      expect(volume).to be_valid
    end
  end
end
