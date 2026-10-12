module Api
  module V1
    module Projects
      class ServicesController < BaseController
        before_action :set_project

        def index
          @services = @project.services.includes(:domains, :cron_schedule).order(:name)
        end

        def create
          result = Api::Services::Create.execute(
            project: @project,
            params: params.permit(
              :name, :service_type, :container_port, :replicas, :command,
              :healthcheck_url, :allow_public_networking, :cron_schedule
            )
          )

          if result.success?
            @service = result.service
            render :show, status: :created
          else
            render_error(result.message)
          end
        end

        private

        def set_project
          projects = ::Projects::VisibleToUser.execute(account_user: current_account_user).projects
          @project = projects.find_by_name!(params[:project_id])
        end
      end
    end
  end
end
