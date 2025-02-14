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
