class AddPodYamlToServices < ActiveRecord::Migration[7.2]
  def change
    add_column :services, :pod_yaml, :jsonb
  end
end
