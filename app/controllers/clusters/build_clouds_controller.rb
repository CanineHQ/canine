class Clusters::BuildCloudsController < Clusters::BaseController
  include StorageHelper

  def show
    @build_cloud = @cluster.build_cloud

    if @build_cloud.blank?
      redirect_to edit_cluster_path(@cluster), alert: "No build cloud found for this cluster"
      return
    end

    render partial: "clusters/build_clouds/show", locals: { cluster: @cluster }
  end

  def edit
    @build_cloud = @cluster.build_cloud

    if @build_cloud.blank?
      redirect_to edit_cluster_path(@cluster), alert: "No build cloud found for this cluster"
      return
    end

    render partial: "clusters/build_clouds/edit", locals: { cluster: @cluster, build_cloud: @build_cloud }
  end

  def update
    @build_cloud = @cluster.build_cloud

    if @build_cloud.blank?
      redirect_to edit_cluster_path(@cluster), alert: "No build cloud found for this cluster"
      return
    end

    if @build_cloud.update(build_cloud_params)
      Clusters::InstallBuildCloudJob.perform_later(@build_cloud)
      render partial: "clusters/build_clouds/show", locals: { cluster: @cluster }
    else
      render partial: "clusters/build_clouds/edit", locals: { cluster: @cluster, build_cloud: @build_cloud }
    end
  end

  def create
    if @cluster.build_cloud.present? && !@cluster.build_cloud.uninstalled?
      redirect_to edit_cluster_path(@cluster), alert: "Build cloud is already installed on this cluster"
      return
    end

    build_cloud = if @cluster.build_cloud.nil?
      @cluster.create_build_cloud!
    else
      @cluster.build_cloud
    end

    Clusters::InstallBuildCloudJob.perform_later(build_cloud)

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

  private

  def build_cloud_params
    params.require(:build_cloud).permit(:replicas, :cpu_requests, :cpu_limits, :memory_requests, :memory_limits)
  end
end
