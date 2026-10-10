module Api
  module V1
    class ProjectsController < BaseController
      before_action :set_project, only: %i[show update deploy restart doctor logs]

      def index
        @projects = ::Projects::VisibleToUser.execute(account_user: current_account_user).projects.includes(:cluster).order(:name).limit(50)
      end

      def show
      end

      def create
        result = Api::Projects::Create.execute(
          user: current_user,
          cluster: find_visible_cluster(params.require(:cluster_id)),
          params: params.permit(
            :name, :provider_id, :repository_url, :branch, :dockerfile_path,
            :context_directory, :predeploy_command, :public_image_url
          )
        )

        if result.success?
          @project = result.project
          render :show, status: :created
        else
          render_error(result.message)
        end
      end

      def update
        result = Api::Projects::Update.execute(
          project: @project,
          user: current_user,
          params: params.permit(*Api::Projects::Update::PROJECT_ATTRIBUTES, *Api::Projects::Update::BUILD_CONFIGURATION_ATTRIBUTES)
        )

        if result.success?
          render :show
        else
          render_error(result.message)
        end
      end

      def logs
        result = Api::Projects::Logs.execute(project: @project, user: current_user, tail_lines: params[:tail_lines] || 100)

        if result.success?
          render json: { pods: result.pods }
        else
          render_error(result.message, status: :bad_gateway)
        end
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

      def doctor
        result = ::Projects::Doctor.execute(project: @project, user: current_user)

        if result.success?
          render json: { checks: result.checks }, status: :ok
        else
          render json: { error: "Failed to run doctor checks" }, status: :unprocessable_entity
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
