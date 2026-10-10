module Api
  module V1
    class BaseController < ActionController::API
      include Pundit::Authorization

      helper_method :current_user, :current_account, :current_account_user

      before_action :default_format_json
      before_action :authenticate_with_api_token!

      rescue_from ActiveRecord::RecordNotFound, with: :not_found
      rescue_from Pundit::NotAuthorizedError, with: :forbidden
      rescue_from ActionController::ParameterMissing do |e|
        render_error(e.message, status: :bad_request)
      end

      private

      def default_format_json
        request.format = :json
      end

      def authenticate_with_api_token!
        token = request.headers["X-API-Key"].presence || bearer_token

        if token.blank?
          render json: { error: "Missing API token" }, status: :unauthorized
          return
        end

        api_token = ApiToken.find_by(access_token: token)

        if api_token.nil? || api_token.expired?
          render json: { error: "Invalid or expired API token" }, status: :unauthorized
          return
        end

        api_token.touch(:last_used_at)
        @current_user = api_token.user
      end

      def bearer_token
        request.authorization.to_s[/\ABearer (.+)\z/, 1]
      end

      def current_user
        @current_user
      end

      # Clusters can be referenced by numeric ID or by name.
      def find_visible_cluster(id_or_name)
        clusters = ::Clusters::VisibleToUser.execute(account_user: current_account_user).clusters
        clusters.find_by(name: id_or_name.to_s) || clusters.find(id_or_name)
      end

      def render_error(message, status: :unprocessable_entity)
        render json: { error: message }, status: status
      end

      def current_account
        @current_account ||= begin
          account_id = request.headers["X-Account-Id"].presence || params[:account_id].presence
          if account_id
            current_user.accounts.friendly.find(account_id)
          else
            current_user.accounts.first
          end
        end
      end

      def current_account_user
        return nil unless current_user && current_account
        @current_account_user ||= AccountUser.find_by(user: current_user, account: current_account)
      end

      def pundit_user
        current_account_user
      end

      def not_found
        render json: { error: "Resource not found" }, status: :not_found
      end

      def forbidden
        render json: { error: "You are not authorized to perform this action" }, status: :forbidden
      end
    end
  end
end
