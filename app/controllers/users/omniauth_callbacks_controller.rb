module Users
  class OmniauthCallbacksController < Devise::OmniauthCallbacksController
    before_action :set_provider, except: [ :failure, :oidc ]
    before_action :set_user, except: [ :failure, :oidc ]

    attr_reader :provider, :user

    def failure
      redirect_to root_path, alert: "Something went wrong"
    end

    def github
      handle_auth "Github"
    end

    def oidc
      sso_provider_id = session["sso_provider_id"]
      sso_provider = SSOProvider.find_by(id: sso_provider_id) if sso_provider_id.present?

      if sso_provider
        @user = find_or_create_oidc_user
        handle_oidc_auth(sso_provider)
      else
        redirect_to root_path, alert: "SSO provider not found"
      end
    end

    private

    def find_or_create_oidc_user
      if user_signed_in?
        current_user
      else
        # Find or create user from OIDC data
        create_user
      end
    end

    def handle_oidc_auth(sso_provider)
      # For OIDC, we don't store in Provider model, just authenticate
      if user_signed_in?
        flash[:notice] = "Your #{sso_provider.name} account was connected."
        redirect_to edit_user_registration_path
      else
        sign_in_and_redirect @user, event: :authentication
        # Set account from SSO provider
        session[:account_id] = sso_provider.account_id
        set_flash_message :notice, :success, kind: sso_provider.name
      end

      # Clear SSO session data
      session.delete("sso_provider_id")
      session.delete("sso_account_id")
    end

    def handle_auth(kind)
      if provider.present?
        provider.update(provider_attrs)
      else
        user.providers.create(provider_attrs)
      end

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
          AccountUser.create!(account: account, user: user)
        end

        user
      end
    end
  end
end
