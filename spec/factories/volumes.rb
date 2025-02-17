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
FactoryBot.define do
  factory :volume do
    project
    sequence(:name) { |n| "example-volume-#{n}" }
    mount_path { "/volumes/data" }
    size { "10Gi" }
    access_mode { :read_write_once }
    status { :pending }
  end
end
