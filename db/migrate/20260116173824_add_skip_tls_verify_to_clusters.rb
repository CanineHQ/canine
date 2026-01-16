class AddSkipTlsVerifyToClusters < ActiveRecord::Migration[7.2]
  def change
    add_column :clusters, :skip_tls_verify, :boolean, default: false, null: false
  end
end
