class ApplicationController < ActionController::Base
  include ActionView::Helpers::DateHelper
  impersonates :user
  include Pundit::Authorization
  include Pagy::Backend

  #protect_from_forgery with: :exception
  skip_before_action :verify_authenticity_token

  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :authenticate_user!

  layout :determine_layout

  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found

  protected
    

    def current_account
      return nil unless user_signed_in?
      @current_account ||= current_user.accounts.find_by(id: session[:account_id]) || current_user.accounts.first
    end
    helper_method :current_account
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
      current_user ? "application" : "homepage"
    end

    def record_not_found
      flash[:alert] = "The requested resource could not be found."
      redirect_to root_path
    end
end
