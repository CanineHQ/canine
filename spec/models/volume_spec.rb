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
  pending "add some examples to (or delete) #{__FILE__}"
end
