class AddErrorTrackingUrlToClusters < ActiveRecord::Migration[7.2]
  def change
    add_column :clusters, :error_tracking_url, :string
  end
end
