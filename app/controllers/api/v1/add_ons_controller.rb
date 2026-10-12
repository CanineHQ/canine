# frozen_string_literal: true

module Api
  module V1
    class AddOnsController < BaseController
      before_action :set_add_on, only: %i[show restart logs]

      def index
        @add_ons = ::AddOns::VisibleToUser.execute(account_user: current_account_user).add_ons.includes(:cluster).order(:name).limit(50)
      end

      def show
      end

      def search
        result = Api::AddOns::Search.execute(query: params.require(:q))

        if result.success?
          render json: result.results
        else
          render_error(result.message, status: :bad_gateway)
        end
      end

      def create
        result = Api::AddOns::Create.execute(
          cluster: find_visible_cluster(params.require(:cluster_id)),
          user: current_user,
          params: params.permit(:name, :chart_url, :version, :repository_url, :values_yaml)
        )

        if result.success?
          render json: Api::AddOns::ListViewModel.new([ result.add_on ]).as_json.first, status: :created
        else
          render_error(result.message)
        end
      end

      def restart
        @service.restart
        render json: { message: "Add on #{@add_on.name} has been restarted" }, status: :ok
      end

      def logs
        result = Api::AddOns::Logs.execute(add_on: @add_on, user: current_user, tail_lines: params[:tail_lines] || 100)

        if result.success?
          render json: { pods: result.pods }
        else
          render_error(result.message, status: :bad_gateway)
        end
      end

      private

      def set_add_on
        add_ons = ::AddOns::VisibleToUser.execute(account_user: current_account_user).add_ons
        @add_on = add_ons.find_by!(name: params[:id])
        @service = K8::Helm::Service.create_from_add_on(K8::Connection.new(@add_on, current_user))
      end
    end
  end
end
