class AddDigestToBuilds < ActiveRecord::Migration[7.2]
  def change
    add_column :builds, :digest, :string
  end
end
