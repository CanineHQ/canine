module Users
  class OmniauthCallbacksController < Devise::OmniauthCallbacksController
    before_action :set_provider, only: :github
    before_action :set_user, only: :github

    attr_reader :provider, :user

    def failure
      redirect_to root_path, alert: "Something went wrong"
    end

    def github
      handle_auth "Github"
    end

    # Google is a login method only: unlike GitHub it isn't a git/registry credential,
    # so no Provider record is stored. Users are matched by their verified email.
    def google_oauth2
      unless auth.info.email.present? && auth.extra&.raw_info&.email_verified
        redirect_to new_user_session_path, alert: "Your Google account's email address must be verified."
        return
      end

      @user = current_user || create_user

      if user_signed_in?
        redirect_to after_sign_in_path_for(user)
      elsif user.otp_required_for_login?
        session[:otp_user_id] = user.id
        redirect_to new_two_factor_verification_path
      else
        sign_in_and_redirect user, event: :authentication
        session[:account_id] = user.accounts.first&.id
        set_flash_message :notice, :success, kind: "Google"
      end
    end

    private

    def handle_auth(kind)
      if provider.present?
        provider.update(provider_attrs)
      else
        user.providers.create(provider_attrs)
      end

      user.update!(password_change_required: false) if user.password_change_required?

      if user_signed_in?
        flash[:notice] = "Your #{kind} account was connected."
        redirect_to edit_user_registration_path
      else
        sign_in_and_redirect user, event: :authentication
        session[:account_id] = user.accounts.first.id
        set_flash_message :notice, :success, kind: kind
      end
    end

    def auth
      request.env["omniauth.auth"]
    end

    def set_provider
      @provider = Provider.where(provider: auth.provider, uid: auth.uid).first
    end

    def set_user
      if user_signed_in?
        @user = current_user
      elsif provider.present?
        @user = provider.user
      else
        @user = create_user
      end
    end

    def provider_attrs
      auth_hash = auth.to_hash
      auth_hash.delete("credentials")
      auth_hash["extra"]&.delete("access_token")
      expires_at = auth.credentials.expires_at.present? ? Time.at(auth.credentials.expires_at) : nil
      {
          provider: auth.provider,
          uid: auth.uid,
          auth: auth_hash.to_json,
          expires_at: expires_at,
          access_token: auth.credentials.token,
          access_token_secret: auth.credentials.secret
      }
    end

    def create_user
      ActiveRecord::Base.transaction do
        user = User.find_or_initialize_by(email: auth.info.email.downcase) do |user|
          user.first_name = auth.info.name
          user.password = Devise.friendly_token[0, 20]
          user.save!
        end

        if user.owned_accounts.size.zero?
          account = Account.create!(
            owner: user,
            name: "#{auth.info.name || auth.info.email.split("@").first}'s Account"
          )
          AccountUser.create!(account: account, user: user, role: :owner)
        end

        user
      end
    end
  end
end
