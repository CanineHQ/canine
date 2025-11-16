class CreateResourceConstraints < ActiveRecord::Migration[7.2]
  def change
    create_table :resource_constraints do |t|
      t.references :service, null: false, index: true
      t.bigint :cpu_request
      t.bigint :cpu_limit
      t.bigint :memory_request
      t.bigint :memory_limit
      t.integer :gpu_request

      t.timestamps
    end
  end
end
