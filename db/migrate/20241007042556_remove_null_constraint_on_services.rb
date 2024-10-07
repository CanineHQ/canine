class RemoveNullConstraintOnServices < ActiveRecord::Migration[7.2]
  def change
    change_column_null :services, :command, true
  end
end
