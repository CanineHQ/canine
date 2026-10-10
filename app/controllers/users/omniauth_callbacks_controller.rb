module Users
  class OmniauthCallbacksController < Devise::OmniauthCallbacksController
    before_action :set_provider
    before_action :set_user

    attr_reader :provider, :user

    def failure
      redirect_to root_path, alert: "Something went wrong"
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

      user.update!(password_change_required: false) if user.password_change_required?

      if user_signed_in? && current_user == user
        flash[:notice] = "Your #{kind} account was connected."
        redirect_to edit_user_registration_path
      else
        # Either a fresh login or a GitHub identity that belongs to someone other than the active session:
        # sign in as that identity rather than leaving the leftover session in place.
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
      # Resolve an existing GitHub identity before the session: a GitHub account that already belongs to someone
      # signs in (or re-connects) as that someone, never as whoever a leftover session happened to be. Only a
      # brand-new GitHub (no provider record) attaches to the signed-in user — the genuine "connect my account" flow.
      @user = if provider.present?
        provider.user
      elsif user_signed_in?
        current_user
      else
        create_user
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
