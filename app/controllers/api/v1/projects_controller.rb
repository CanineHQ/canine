module Api
  module V1
    class ProjectsController < BaseController
      before_action :set_project, only: %i[show deploy restart]

      def index
        @projects = ::Projects::VisibleToUser.execute(account_user: current_account_user).projects.order(:name).limit(50)
      end

      def show
      end

      def deploy
        result = ::Projects::DeployLatestCommit.execute(
          project: @project,
          current_user: current_user,
          skip_build: params[:skip_build]
        )

        if result.success?
          render json: { message: "Deploying project #{@project.name}.", build_id: result.build.id }, status: :ok
        else
          render json: { error: "Failed to deploy project" }, status: :unprocessable_entity
        end
      end

      def restart
        result = ::Projects::Restart.execute(connection: K8::Connection.new(@project, current_user))

        if result.success?
          render json: { message: "All services have been restarted" }, status: :ok
        else
          render json: { error: "Failed to restart all services" }, status: :unprocessable_entity
        end
      end

      private

      def set_project
        projects = ::Projects::VisibleToUser.execute(account_user: current_account_user).projects
        @project = projects.find_by_name!(params[:id])
      end
    end
  end
end
