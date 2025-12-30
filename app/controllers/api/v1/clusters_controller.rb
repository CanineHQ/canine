module Api
  module V1
    class ClustersController < BaseController
      before_action :set_cluster, only: %i[download_kubeconfig]

      def index
        clusters = ::Clusters::VisibleToUser.execute(account_user: current_account_user).clusters
        render json: clusters.map { |c| cluster_json(c) }
      end

      def download_kubeconfig
        connection = K8::Connection.new(@cluster, current_user)
        render json: { kubeconfig: connection.kubeconfig }
      end

      private

      def set_cluster
        clusters = ::Clusters::VisibleToUser.execute(account_user: current_account_user).clusters
        @cluster = clusters.find(params[:id])
      end

      def cluster_json(cluster)
        {
          id: cluster.id,
          name: cluster.name,
          cluster_type: cluster.cluster_type,
          status: cluster.status,
          created_at: cluster.created_at,
          updated_at: cluster.updated_at
        }
      end
    end
  end
end
