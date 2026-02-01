module Api
  module V1
    module Projects
      class ProcessesController < BaseController
        before_action :set_project

        def index
          client = K8::Client.new(active_connection)
          @pods = client.get_pods(namespace: @project.namespace).sort_by { |pod| pod.metadata.name }.first(50)
        end

        def show
          client = K8::Client.new(active_connection)
          @pod = client.get_pods(namespace: @project.namespace, field_selector: "metadata.name=#{params[:id]}").first
        end

        def create
          client = K8::Client.new(active_connection)
          kubectl = K8::Kubectl.new(active_connection)
          pod = K8::Stateless::Pod.new(@project)
          kubectl.apply_yaml(pod.to_yaml)
          @pod = client.get_pods(namespace: @project.namespace, field_selector: "metadata.name=#{pod.name}").first

          render :create, status: :created
        end

        def destroy
          client = K8::Client.new(active_connection)
          client.delete_pod(params[:id], @project.namespace)

          render json: { message: "Pod #{params[:id]} terminating" }, status: :ok
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
