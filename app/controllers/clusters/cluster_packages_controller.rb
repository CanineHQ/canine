class Clusters::ClusterPackagesController < Clusters::BaseController
  def create
    definition = ClusterPackage.definitions_for(current_account).find { |d| d["name"] == params[:name] }
    return head :not_found unless definition

    config = params[:config]&.permit!&.to_h || {}
    package = @cluster.cluster_packages.find_or_initialize_by(name: params[:name])
    # Merge so settings Canine keeps in the config (like the registry's password) survive a reinstall
    package.update!(status: :pending, config: (package.config || {}).merge(config))

    Clusters::InstallPackageJob.perform_later(package, current_user)
    render partial: "clusters/cluster_packages/package_row",
           locals: { cluster: @cluster, definition: definition, package: package }
  end

  def destroy
    package = @cluster.cluster_packages.find(params[:id])
    Clusters::UninstallPackageJob.perform_later(package, current_user)
    render partial: "clusters/cluster_packages/package_row",
           locals: { cluster: @cluster, definition: package.definition, package: package }
  end

  def sync
    Clusters::SyncPackagesJob.perform_later(@cluster, current_user)
    redirect_to edit_cluster_path(@cluster), notice: "Syncing package statuses..."
  end
end
