class AddServiceAccountCredentialsToClusters < ActiveRecord::Migration[7.2]
  def change
    add_column :clusters, :server_url, :string
    add_column :clusters, :certificate_authority_data, :text
    add_column :clusters, :service_account_token, :text
    add_column :clusters, :unreachable_since, :datetime
  end
end
