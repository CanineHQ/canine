class AllowNullWebhookUrlOnNotifiers < ActiveRecord::Migration[7.2]
  def change
    change_column_null :notifiers, :webhook_url, true
  end
end
