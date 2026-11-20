module Api
  module V1
    class BaseController < ActionController::API
      include Pundit::Authorization

      helper_method :current_user, :current_account, :current_account_user

      before_action :authenticate_with_api_token!

      rescue_from ActiveRecord::RecordNotFound, with: :not_found
      rescue_from Pundit::NotAuthorizedError, with: :forbidden

      private

      # Accepts an API token in X-API-Key, or an OAuth access token (from /oauth/token, e.g. Canine Connect's
      # browser sign-in) as `Authorization: Bearer`.
      #
      # Only tokens granted an API scope get in. Canine is also the sign-in provider for the auth proxies in front
      # of deployed apps, whose tokens carry only openid/profile/email: those prove who someone is and must not act
      # as them here. A token with `read` alone is limited to requests that change nothing.
      OAUTH_READ_SCOPES = %w[public read write].freeze
      OAUTH_WRITE_SCOPES = %w[public write].freeze

      def authenticate_with_api_token!
        token = request.headers["X-API-Key"]
        return authenticate_with_oauth_token! if token.blank? && request.authorization.to_s.start_with?("Bearer ")

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

      def authenticate_with_oauth_token!
        oauth_token = Doorkeeper::OAuth::Token.authenticate(request, *Doorkeeper.config.access_token_methods)

        user = User.find_by(id: oauth_token.resource_owner_id) if oauth_token&.accessible?
        if user.nil?
          render json: { error: "Invalid or expired access token" }, status: :unauthorized
          return
        end

        required_scopes = request.get? || request.head? ? OAUTH_READ_SCOPES : OAUTH_WRITE_SCOPES
        unless oauth_token.includes_scope?(*required_scopes)
          render json: { error: "This access token is not allowed to do that" }, status: :forbidden
          return
        end

        @current_user = user
      end

      def current_user
        @current_user
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
