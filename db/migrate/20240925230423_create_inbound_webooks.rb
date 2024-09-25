class CreateInboundWebooks < ActiveRecord::Migration[7.2]
  def change
    create_table :inbound_webooks do |t|
      t.text :body
      t.integer :status, default: 0
      t.timestamps
    end
  end
end
