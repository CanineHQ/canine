class Users::RegistrationsController < Devise::RegistrationsController
  layout 'homepage', only: [ :new, :create ]

  protected
   def update_resource(resource, params)
    if account_update_params[:password].blank?
      params.delete("password")
      params.delete("password_confirmation")
      params.delete("current_password")
      resource.update_without_password(params)
    else
      resource.update_with_password(params)
    end
  end
end
