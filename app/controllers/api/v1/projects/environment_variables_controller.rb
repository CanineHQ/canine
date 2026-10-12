module Api
  module V1
    module Projects
      class EnvironmentVariablesController < BaseController
        before_action :set_project
        before_action :set_environment_variable, only: %i[show destroy]

        def index
          @environment_variables = @project.environment_variables.order(:name)
        end

        def show
          render json: Api::EnvironmentVariables::ShowViewModel.new(@environment_variable, reveal: true).as_json
        end

        def create
          params.require(:name)
          params.require(:value)
          result = Api::EnvironmentVariables::Upsert.execute(
            project: @project,
            user: current_user,
            params: params.permit(:name, :value, :storage_type)
          )

          if result.success?
            render json: Api::EnvironmentVariables::ShowViewModel.new(result.environment_variable).as_json,
                   status: result.created ? :created : :ok
          else
            render_error(result.message)
          end
        end

        def destroy
          @environment_variable.destroy!
          render json: { message: "Environment variable #{@environment_variable.name} deleted. Redeploy for the change to take effect." }
        end

        private

        def set_project
          projects = ::Projects::VisibleToUser.execute(account_user: current_account_user).projects
          @project = projects.find_by_name!(params[:project_id])
        end

        def set_environment_variable
          @environment_variable = @project.environment_variables.find_by!(name: params[:id].upcase)
        end
      end
    end
  end
end
