class AddHealthcheckUrlToServices < ActiveRecord::Migration[7.2]
  def change
    add_column :services, :healthcheck_url, :string
    add_column :services, :allow_public_networking, :boolean, default: false
    add_column :services, :status, :integer
    add_column :services, :last_health_checked_at, :datetime
  end
end
