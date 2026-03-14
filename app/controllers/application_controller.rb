class ApplicationController < ActionController::Base
  include ActionView::Helpers::DateHelper
  impersonates :user
  include Pundit::Authorization
  include Pagy::Backend

  protect_from_forgery with: :exception

  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :authenticate_user!
  before_action :check_password_change_required
  before_action :check_two_factor_required

  layout :determine_layout

  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
  rescue_from Portainer::Client::MissingCredentialError, with: :missing_portainer_credential
  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  protected
    def current_account
      return nil unless user_signed_in?
      @current_account ||= current_user.accounts.find_by(id: session[:account_id]) || current_user.accounts.first

      @current_account
    end
    helper_method :current_account

    def current_account_user
      return nil unless user_signed_in? && current_account
      @current_account_user ||= AccountUser.find_by(user: current_user, account: current_account)
    end
    helper_method :current_account_user

    def time_ago(t)
      if t.present?
        "#{time_ago_in_words(t)} ago"
      else
        "Never"
      end
    end
    helper_method :time_ago

    def configure_permitted_parameters
      devise_parameter_sanitizer.permit(:sign_up, keys: [ :name ])
      devise_parameter_sanitizer.permit(:account_update, keys: [ :name, :avatar ])
    end

  private
    def determine_layout
      return "homepage" if doorkeeper_controller?
      current_user ? "application" : "homepage"
    end

    def doorkeeper_controller?
      self.class.module_parent_name == "Doorkeeper"
    end

    def record_not_found
      flash[:alert] = "The requested resource could not be found."
      redirect_to root_path
    end

    def pundit_user
      current_account_user
    end

    def missing_portainer_credential
      redirect_to providers_path, alert: "Please add your Portainer API token to continue."
    end

    def user_not_authorized
      flash[:alert] = "You are not authorized to perform this action."
      redirect_back(fallback_location: root_path)
    end

    def check_two_factor_required
      return unless Rails.application.config.enable_2fa
      return if devise_controller?
      return unless user_signed_in?
      return if true_user != current_user

      if current_user.two_factor_enabled?
        return if session[:otp_verified_at].present?
        redirect_to two_factor_verification_path
      elsif Rails.application.config.require_2fa
        redirect_to new_two_factor_setup_path, alert: "You must enable two-factor authentication to continue."
      end
    end

    def check_password_change_required
      return if devise_controller?
      return unless user_signed_in?
      return if true_user != current_user # Skip when impersonating
      return unless current_user.password_change_required?

      redirect_to password_change_path, alert: "Please change your password to continue."
    end
end
