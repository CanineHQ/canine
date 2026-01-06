module Api
  module V1
    class BuildsController < BaseController
      before_action :set_build, only: %i[show kill]

      def index
        @builds = accessible_builds
          .where(status: :in_progress)
          .or(accessible_builds.where(created_at: 24.hours.ago..))
          .order(created_at: :desc)
        if params[:project_id].present?
          project = ::Projects::VisibleToUser.execute(account_user: current_account_user).projects.find_by_name!(params[:project_id])
          @builds = @builds.where(project_id: project.id)
        end
        @builds = @builds.limit(50)
      end

      def show
      end

      def kill
        if @build.in_progress?
          @build.killed!
          @build.error("Build was killed by #{current_user.email}")
          render json: { message: "Build has been killed." }, status: :ok
        else
          render json: { error: "Build cannot be killed (not in progress)." }, status: :unprocessable_entity
        end
      end

      private

      def accessible_builds
        project_ids = ::Projects::VisibleToUser.execute(account_user: current_account_user).projects.pluck(:id)
        Build.where(project_id: project_ids)
      end

      def set_build
        @build = accessible_builds.find(params[:id])
      end
    end
  end
end
