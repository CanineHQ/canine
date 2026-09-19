module Api
  module V1
    module Projects
      class WorkbenchesController < BaseController
        before_action :set_project

        def show
          unless @project.development_environment?
            render json: { error: "Project is not a development environment" }, status: :unprocessable_entity
            return
          end

          client = K8::Client.new(active_connection)
          pods = client.get_pods(namespace: @project.namespace).select { |pod| pod.status.phase == "Running" }
          @pod = pods.first

          if @pod.nil?
            render json: { error: "No running workbench pod found" }, status: :not_found
            return
          end

          config = @project.child_development_environment&.parent_project&.development_environment_configuration
          @workspace_mount_path = config&.workspace_mount_path || "/workspace"

          render json: {
            pod_name: @pod.metadata.name,
            namespace: @project.namespace,
            container: @project.name,
            workspace_mount_path: @workspace_mount_path,
            cluster_name: @project.cluster.name
          }
        end

        private

        def active_connection
          @active_connection ||= K8::Connection.new(@project, current_user)
        end

        def set_project
          projects = ::Projects::VisibleToUser.execute(account_user: current_account_user).projects
          @project = projects.find_by_name!(params[:project_id])
        end
      end
    end
  end
end
