class AddRepositoryUrlToAddOns < ActiveRecord::Migration[7.2]
  def up
    add_column :add_ons, :repository_url, :string
    add_column :add_ons, :artifact_hub_package_id, :string

    # Backfill repository_url, artifact_hub_package_id, and rename package_details to artifact_hub
    AddOn.find_each do |add_on|
      next unless add_on.metadata.present?

      package_details = add_on.metadata['package_details']
      if package_details.present?
        # Extract and set repository_url
        repo_url = package_details.dig('repository', 'url')
        if repo_url.present?
          add_on.update_column(:repository_url, repo_url)
        end

        # Set artifact_hub_package_id as helm/chart_url
        if add_on.chart_url.present?
          add_on.update_column(:artifact_hub_package_id, "helm/#{add_on.chart_url}")
        end

        # Move package_details to artifact_hub
        add_on.metadata['artifact_hub'] = package_details
        add_on.metadata.delete('package_details')

        # Extract display fields (logo, display_name, description)
        AddOns::SetPackageDetails.pluck_styles(add_on, package_details)

        add_on.save!
      end
    end

    # Add NOT NULL constraint after backfill
    change_column_null :add_ons, :repository_url, false
  end

  def down
    # Move artifact_hub back to package_details
    AddOn.find_each do |add_on|
      next unless add_on.metadata.present?

      artifact_hub = add_on.metadata['artifact_hub']
      if artifact_hub.present?
        add_on.metadata['package_details'] = artifact_hub
        add_on.metadata.delete('artifact_hub')
        add_on.save!
      end
    end

    remove_column :add_ons, :artifact_hub_package_id
    remove_column :add_ons, :repository_url
  end
end
