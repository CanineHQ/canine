class CreateApiTokens < ActiveRecord::Migration[7.2]
  def change
    create_table :api_tokens do |t|
      t.references :user, null: false, foreign_key: true
      t.string :access_token, null: false
      t.datetime :last_used_at
      t.datetime :expires_at
      t.timestamps
    end
  end
end
