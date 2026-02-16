class AddOns::SetPackageDetails
  extend LightService::Action
  expects :add_on

  def self.pluck_styles(add_on, artifact_hub_response = nil)
    # Check if this is a curated chart from charts.yml
    chart_definition = add_on.chart_definition

    if chart_definition.present?
      # Path 1: Use values from charts.yml (overrides Artifact Hub)
      add_on.metadata['logo'] = chart_definition['logo']
      add_on.metadata['display_name'] = chart_definition['display_name']
      add_on.metadata['description'] = chart_definition['description'] if chart_definition['description'].present?
    elsif artifact_hub_response.present?
      # Path 2: Use values from Artifact Hub
      add_on.metadata['logo'] = artifact_hub_response['logo']
      add_on.metadata['display_name'] = artifact_hub_response['display_name']
      add_on.metadata['description'] = artifact_hub_response['description']
    else
      # Path 3: Minimal display fields (custom repository)
      # Extract chart name from chart_url
      chart_name = add_on.chart_url&.split('/')&.last
      add_on.metadata['logo'] = nil
      add_on.metadata['display_name'] = chart_name
    end
  end

  executed do |context|
    add_on = context.add_on
    artifact_hub_response = nil

    # Fetch from Artifact Hub if artifact_hub_package_id is present
    if add_on.artifact_hub_package_id.present?
      result = AddOns::FetchChartDetailsFromArtifactHub.execute(
        artifact_hub_package_id: add_on.artifact_hub_package_id
      )

      if result.failure?
        add_on.errors.add(:base, "Failed to fetch package details from Artifact Hub")
        context.fail_and_return!("Failed to fetch package details")
        return
      end

      artifact_hub_response = result.response

      # Set version if not already set
      add_on.version ||= artifact_hub_response['version']
    end

    # Extract display fields
    pluck_styles(add_on, artifact_hub_response)
  end
end
