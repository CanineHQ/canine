module Api
  module V1
    class ClustersController < BaseController
      before_action :set_cluster, only: %i[download_kubeconfig]

      def index
        @clusters = ::Clusters::VisibleToUser.execute(account_user: current_account_user).clusters.order(:name).limit(50)
      end

      def download_kubeconfig
        connection = K8::Connection.new(@cluster, current_user)
        render json: { kubeconfig: connection.kubeconfig }
      end

      private

      def set_cluster
        clusters = ::Clusters::VisibleToUser.execute(account_user: current_account_user).clusters
        @cluster = clusters.find_by_name!(params[:id])
      end
    end
  end
end
