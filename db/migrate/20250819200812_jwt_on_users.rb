class JwtOnUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :clusters, :external_id, :string
    change_column_null :clusters, :kubeconfig, true
  end
end
