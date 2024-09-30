class ApplicationController < ActionController::Base
  impersonates :user
  include Pundit::Authorization
  include Pagy::Backend

  #protect_from_forgery with: :exception
  skip_before_action :verify_authenticity_token

  before_action :configure_permitted_parameters, if: :devise_controller?

  protected

    def configure_permitted_parameters
      devise_parameter_sanitizer.permit(:sign_up, keys: [ :name ])
      devise_parameter_sanitizer.permit(:account_update, keys: [ :name, :avatar ])
    end
end
