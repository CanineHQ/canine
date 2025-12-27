class AddVersionToAddOns < ActiveRecord::Migration[7.2]
  def up
    add_column :add_ons, :version, :string

    AddOn.find_each do |add_on|
      version = extract_version_from_metadata(add_on) || fetch_version_from_artifact_hub(add_on)

      if version.present?
        add_on.update_column(:version, version)
      else
        Rails.logger.warn("Could not determine version for AddOn #{add_on.id} (#{add_on.name})")
      end
    end

    change_column_null :add_ons, :version, false
  end

  def down
    remove_column :add_ons, :version
  end

  private

  def extract_version_from_metadata(add_on)
    add_on.metadata.dig("package_details", "version")
  end

  def fetch_version_from_artifact_hub(add_on)
    return nil if add_on.chart_url.blank?

    response = HTTParty.get(
      "https://artifacthub.io/api/v1/packages/helm/#{add_on.chart_url}",
      timeout: 10
    )

    return nil unless response.success?

    response.parsed_response["version"]
  rescue StandardError => e
    Rails.logger.error("Failed to fetch version from Artifact Hub for AddOn #{add_on.id}: #{e.message}")
    nil
  end
end
