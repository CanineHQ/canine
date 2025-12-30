module Api
  module V1
    class MeController < BaseController
      def show
        render json: {
          id: current_user.id,
          email: current_user.email,
          name: current_user.name,
          created_at: current_user.created_at
        }
      end
    end
  end
end
