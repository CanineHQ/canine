class Clusters::BuildCloudsController < Clusters::BaseController
  def create
    if @cluster.build_cloud.present? && !@cluster.build_cloud.uninstalled?
      redirect_to edit_cluster_path(@cluster), alert: "Build cloud is already installed on this cluster"
      return
    end

    Clusters::InstallBuildCloudJob.perform_later(@cluster)
    redirect_to edit_cluster_path(@cluster), notice: "Build cloud installation started. This may take a few minutes..."
  end

  def destroy
    @build_cloud = @cluster.build_cloud

    if @build_cloud.blank?
      redirect_to edit_cluster_path(@cluster), alert: "No build cloud found for this cluster"
      return
    end

    if @build_cloud.uninstalling?
      redirect_to edit_cluster_path(@cluster), alert: "Build cloud is already being uninstalled"
      return
    end

    Clusters::DestroyBuildCloudJob.perform_later(@cluster)
    redirect_to edit_cluster_path(@cluster), notice: "Build cloud removal started. This may take a few minutes..."
  end
end
