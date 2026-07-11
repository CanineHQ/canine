class Users::RegistrationsController < Devise::RegistrationsController
  layout 'homepage', only: [ :new, :create ]
  before_action :disable_registration_for_self_hosted

  def create
    ActiveRecord::Base.transaction do
      super do |user|
        account = Account.create!(name: "#{user.first_name}'s Account", owner: user) if user.persisted?
        AccountUser.create!(account:, user:, role: :owner)
      end
    end
  rescue ActiveRecord::RecordInvalid => e
    render :new, status: :unprocessable_entity
  end

  protected

  def disable_registration_for_self_hosted
    return if Rails.application.config.cloud_mode

    redirect_to new_user_session_path, alert: "Sign up is disabled."
  end

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
