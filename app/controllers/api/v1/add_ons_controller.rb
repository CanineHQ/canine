# frozen_string_literal: true

module Api
  module V1
    class AddOnsController < BaseController
      before_action :set_add_on, only: %i[show restart]

      def index
        @add_ons = ::AddOns::VisibleToUser.execute(account_user: current_account_user).add_ons.includes(:cluster).order(:name).limit(50)
      end

      def show
      end

      def restart
        @service.restart
        render json: { message: "Add on #{@add_on.name} has been restarted" }, status: :ok
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
