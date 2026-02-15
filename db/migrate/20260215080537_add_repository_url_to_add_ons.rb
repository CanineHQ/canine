class AddRepositoryUrlToAddOns < ActiveRecord::Migration[7.2]
  def up
    add_column :add_ons, :repository_url, :string

    # Backfill repository_url from existing metadata
    AddOn.find_each do |add_on|
      next unless add_on.metadata.present?

      repo_url = add_on.metadata.dig('package_details', 'repository', 'url')
      if repo_url.present?
        add_on.update_column(:repository_url, repo_url)
      end
    end

    # Add NOT NULL constraint after backfill
    change_column_null :add_ons, :repository_url, false
  end

  def down
    remove_column :add_ons, :repository_url
  end
end
