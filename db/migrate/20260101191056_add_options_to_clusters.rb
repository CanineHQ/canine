class AddOptionsToClusters < ActiveRecord::Migration[7.2]
  def change
    add_column :clusters, :options, :jsonb, default: {}, null: false
  end
end
