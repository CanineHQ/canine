module Api
  module V1
    class ProvidersController < BaseController
      def index
        @providers = current_user.providers.order(:created_at)
      end

      def create
        result = Api::Providers::Create.execute(
          user: current_user,
          params: params.permit(:type, :access_token, :username, :registry_url)
        )

        if result.success?
          @provider = result.provider
          render :show, status: :created
        else
          render_error(result.message)
        end
      end
    end
  end
end
