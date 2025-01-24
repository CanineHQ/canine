class AddChartUrlToAddOns < ActiveRecord::Migration[7.2]
  def change
    add_column :add_ons, :chart_url, :string
  end
end
