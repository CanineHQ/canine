module Api
  module V1
    class ClustersController < BaseController
      before_action :set_cluster, only: %i[show download_kubeconfig]

      def index
        @clusters = ::Clusters::VisibleToUser.execute(account_user: current_account_user).clusters.order(:name).limit(50)
      end

      def show
      end

      def create
        kubeconfig = params.require(:kubeconfig)
        kubeconfig = kubeconfig.to_unsafe_h if kubeconfig.is_a?(ActionController::Parameters)
        result = Api::Clusters::Create.execute(
          account_user: current_account_user,
          params: params.permit(:name, :cluster_type, :ip_address).to_h.merge(kubeconfig: kubeconfig)
        )

        if result.success?
          @cluster = result.cluster
          render :show, status: :created
        else
          render_error(result.message)
        end
      end

      def download_kubeconfig
        connection = K8::Connection.new(@cluster, current_user)
        render json: { kubeconfig: connection.kubeconfig }
      end

      private

      def set_cluster
        @cluster = find_visible_cluster(params[:id])
      end
    end
  end
end
