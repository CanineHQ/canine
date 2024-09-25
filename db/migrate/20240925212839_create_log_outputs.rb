class CreateLogOutputs < ActiveRecord::Migration[7.2]
  def change
     create_table :log_outputs do |t|
      t.bigint :loggable_id, null: false
      t.string :loggable_type, null: false
      t.text :output

      t.timestamps
    end
  end
end
