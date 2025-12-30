module Api
  module V1
    module Projects
      class ProcessesController < BaseController
        before_action :set_project

        def index
          client = K8::Client.new(K8::Connection.new(@project.cluster, current_user))
          pods = client.get_pods(namespace: @project.namespace)

          render json: pods.map { |pod| pod_json(pod) }
        end

        def create
          connection = K8::Connection.new(@project, current_user)
          kubectl = K8::Kubectl.new(connection)
          pod = K8::Stateless::Pod.new(@project)
          kubectl.apply_yaml(pod.to_yaml)

          render json: { message: "One off pod #{pod.name} created", pod_name: pod.name, pod_id: pod.id }, status: :created
        end

        private

        def set_project
          projects = ::Projects::VisibleToUser.execute(account_user: current_account_user).projects
          @project = projects.find(params[:project_id])
        end

        def pod_json(pod)
          {
            name: pod.metadata.name,
            namespace: pod.metadata.namespace,
            status: pod.status.phase,
            created_at: pod.metadata.creationTimestamp,
            labels: pod.metadata.labels&.to_h
          }
        end
      end
    end
  end
end
