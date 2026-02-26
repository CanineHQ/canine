class Clusters::ClusterPackagesController < Clusters::BaseController
  def create
    definition = ClusterPackage.definitions.find { |d| d["name"] == params[:name] }
    return head :not_found unless definition

    config = params[:config]&.permit!&.to_h || {}
    package = @cluster.cluster_packages.find_or_initialize_by(name: params[:name])
    package.update!(status: :pending, config: config)

    Clusters::InstallPackageJob.perform_later(package, current_user)
    redirect_to edit_cluster_path(@cluster), notice: "Installing #{definition['display_name']}..."
  end

  def destroy
    package = @cluster.cluster_packages.find(params[:id])
    Clusters::UninstallPackageJob.perform_later(package, current_user)
    redirect_to edit_cluster_path(@cluster), notice: "Uninstalling #{package.definition&.dig('display_name') || package.name}..."
  end
end
