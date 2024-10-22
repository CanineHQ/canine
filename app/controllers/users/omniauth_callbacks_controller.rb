module Users
  class OmniauthCallbacksController < Devise::OmniauthCallbacksController
    before_action :set_provider, except: [ :failure ]
    before_action :set_user, except: [ :failure ]

    attr_reader :provider, :user

    def failure
      redirect_to root_path, alert: "Something went wrong"
    end

    def facebook
      handle_auth "Facebook"
    end

    def twitter
      handle_auth "Twitter"
    end

    def github
      handle_auth "Github"
    end

    private

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
      elsif User.where(email: auth.info.email).any?
        # 5. User is logged out and they login to a new account which doesn't match their old one
        flash[:alert] = "An account with this email already exists. Please sign in with that account before connecting your #{auth.provider.titleize} account."
        redirect_to new_user_session_path
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
        user = User.create!(
          email: auth.info.email,
          # name: auth.info.name,
          password: Devise.friendly_token[0, 20]
        )
        account = Account.create!(
          owner: user,
          name: "#{auth.info.name || auth.info.email.split("@").first}'s Account"
        )
        AccountUser.create!(account: account, user: user)
        user
      end
    end
  end
end
