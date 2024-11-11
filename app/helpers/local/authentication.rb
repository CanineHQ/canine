module Local::Authentication
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_user!
    before_action :set_github_token_if_not_exists
  end

  def set_github_token_if_not_exists
    if current_user.providers.empty?
      # Redirect to github
      redirect_to github_token_path
    end
  end

  def current_user
    @current_user
  end

  def current_account
    @current_account
  end

  def authenticate_user!
    if User.count.zero?
      Local::CreateDefaultUser.execute
    end
    if ENV["CANINE_USERNAME"].presence && ENV["CANINE_PASSWORD"].presence
      authenticate_or_request_with_http_basic do |username, password|
        @current_user = User.find_by!(email: "#{username}@example.com")
        @current_account = @current_user.accounts.first
      end
    else
      @current_user = User.first
      @current_account = @current_user.accounts.first
    end
  rescue StandardError => e
    Rails.logger.error "Error authenticating user: #{e.message}"
    # Logout http basic auth
    request_http_basic_authentication
  end
end
