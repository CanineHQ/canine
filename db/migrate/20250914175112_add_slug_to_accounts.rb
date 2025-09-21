class AddSlugToAccounts < ActiveRecord::Migration[7.2]
  def up
    add_column :accounts, :slug, :string

    # Backfill existing accounts with slugs
    Account.reset_column_information
    Account.find_each do |account|
      account.slug = account.name.parameterize
      # Handle duplicates by appending a number
      base_slug = account.slug
      counter = 1
      while Account.where.not(id: account.id).exists?(slug: account.slug)
        account.slug = "#{base_slug}-#{counter}"
        counter += 1
      end
      account.save!(validate: false)
    end

    # Now make the column non-nullable and add unique index
    change_column_null :accounts, :slug, false
    add_index :accounts, :slug, unique: true
  end

  def down
    remove_index :accounts, :slug
    remove_column :accounts, :slug
  end
end
