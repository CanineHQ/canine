class CreateIngressEndpointsAndMigrateDomains < ActiveRecord::Migration[7.2]
  def up
    create_table :ingress_endpoints do |t|
      t.string :endpointable_type, null: false
      t.bigint :endpointable_id, null: false
      t.string :endpoint_name, null: false
      t.integer :port, null: false, default: 80
      t.timestamps
    end

    add_index :ingress_endpoints, [ :endpointable_type, :endpointable_id, :endpoint_name, :port ],
              unique: true, name: "index_ingress_endpoints_uniqueness"

    add_column :domains, :ingress_endpoint_id, :bigint

    # Backfill: create IngressEndpoint for each service that has domains
    execute <<-SQL
      INSERT INTO ingress_endpoints (endpointable_type, endpointable_id, endpoint_name, port, created_at, updated_at)
      SELECT DISTINCT 'Service', services.id, services.name || '-service', 80, NOW(), NOW()
      FROM services
      INNER JOIN domains ON domains.service_id = services.id
    SQL

    # Update domains to point to their new ingress_endpoint
    execute <<-SQL
      UPDATE domains
      SET ingress_endpoint_id = ingress_endpoints.id
      FROM ingress_endpoints
      WHERE ingress_endpoints.endpointable_type = 'Service'
        AND ingress_endpoints.endpointable_id = domains.service_id
    SQL

    change_column_null :domains, :ingress_endpoint_id, false
    remove_reference :domains, :service, index: true, foreign_key: false
    add_index :domains, [ :ingress_endpoint_id, :domain_name ], unique: true
  end

  def down
    add_reference :domains, :service, index: true, foreign_key: false

    # Backfill service_id from ingress_endpoint
    execute <<-SQL
      UPDATE domains
      SET service_id = ingress_endpoints.endpointable_id
      FROM ingress_endpoints
      WHERE ingress_endpoints.id = domains.ingress_endpoint_id
        AND ingress_endpoints.endpointable_type = 'Service'
    SQL

    remove_index :domains, [ :ingress_endpoint_id, :domain_name ]
    remove_column :domains, :ingress_endpoint_id

    drop_table :ingress_endpoints
  end
end
