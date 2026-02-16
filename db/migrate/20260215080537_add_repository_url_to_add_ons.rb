class AddRepositoryUrlToAddOns < ActiveRecord::Migration[7.2]
  def up
    add_column :add_ons, :repository_url, :string
    add_column :add_ons, :artifact_hub_package_id, :string

    # Backfill repository_url, artifact_hub_package_id, and rename package_details to artifact_hub
    AddOn.find_each do |add_on|
      package_details = add_on.metadata&.dig('package_details')

      if package_details.present?
        # Extract repository_url from package_details
        repo_url = package_details.dig('repository', 'url')
        add_on.update_column(:repository_url, repo_url) if repo_url.present?

        # Set artifact_hub_package_id as helm/chart_url
        add_on.update_column(:artifact_hub_package_id, "helm/#{add_on.chart_url}") if add_on.chart_url.present?

        # Move package_details to artifact_hub
        add_on.metadata['artifact_hub'] = package_details
        add_on.metadata.delete('package_details')

        # Extract display fields (logo, display_name, description)
        AddOns::SetPackageDetails.pluck_styles(add_on, package_details)
        puts "#{add_on.name}-#{add_on.id}-#{repo_url}"
        add_on.save!
      end

      # Fallback: derive repository_url from chart definition if still blank
      if add_on.repository_url.blank? && add_on.chart_url.present?
        chart_def = add_on.chart_definition
        if chart_def.present? && chart_def['repository_url'].present?
          add_on.update_column(:repository_url, chart_def['repository_url'])
        end
      end
    end

    # Add NOT NULL constraint after backfill
    change_column_null :add_ons, :repository_url, false

    # Remove NOT NULL constraint on chart_type (no longer needed)
    change_column_null :add_ons, :chart_type, true
  end

  def down
    change_column_null :add_ons, :chart_type, false

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
