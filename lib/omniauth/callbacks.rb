module Omniauth
  module Callbacks
    Devise.omniauth_configs.keys.each do |provider|
      define_method provider do
        redirect_to root_path, alert: t("something_went_wrong") if auth.nil?

        if (signed_id = omniauth_params["record"])
          # Handle authentication to another model
          record = GlobalID::Locator.locate_signed(signed_id, for: "oauth")

          ConnectedProvider.where(owner: record).first_or_initialize.update(connected_provider_params)
          run_connected_callback(connected_provider)
          redirect_to(omniauth_params.fetch("redirect_to", record) || root_path)
        elsif connected_provider.present?
          # Account has already been connected before
          handle_previously_connected(connected_provider)

        elsif user_signed_in?
          # User is signed in, but hasn't connected this account before
          attach_provider

        elsif User.exists?(email: auth.info.email)
          # We haven't seen this account before, but we have an existing user with a matching email
          flash.alert = "Account exists"
          redirect_to new_user_session_path

        else
          # We've never seen this user before, so let's sign them up
          create_user
        end
      end
    end

    def failure
      redirect_to root_path, alert: "Something went wrong"
    end

    private

    def handle_previously_connected(connected_provider)
      # Update connected account attributes
      connected_provider.update(connected_provider_params)

      if user_signed_in? && connected_provider.owner != current_user
        redirect_to root_path, alert: "Connected to another account"
      elsif user_signed_in?
        run_connected_callback(connected_provider)
        success_message!(kind: auth.provider)
        redirect_to after_connect_redirect_path
      else
        sign_in_and_redirect connected_provider.owner, event: :authentication
        run_connected_callback(connected_provider)
        success_message!(kind: auth.provider)
      end
    end

    def create_user
      user = User.new(
        email: auth.info.email,
        name: auth.info.name
      )
      user.password = ::Devise.friendly_token[0, 20] if user.respond_to?(:password=)
      user.connected_providers.new(connected_provider_params)
      user.save!

      sign_in_and_redirect(user, event: :authentication)
      run_connected_callback(user.connected_providers.last)
      success_message!(kind: auth.provider)
    end

    def attach_provider
      connected_provider = current_user.connected_providers.create(connected_provider_params)
      run_connected_callback(connected_provider)

      redirect_to after_connect_redirect_path
      success_message!(kind: auth.provider)
    end

    def run_connected_callback(connected_provider)
      method = "#{auth.provider.to_s.underscore}_connected"
      send(method.to_sym, connected_provider) if respond_to?(method)
    end

    def auth
      @auth ||= request.env["omniauth.auth"]
    end

    def omniauth_params
      request.env["omniauth.params"]
    end

    def expires_at
      creds = auth.credentials
      return Time.at(creds.expires_at).utc if creds.expires_at.present?
      Time.now.utc + creds.expires_in if creds.expires_in.present?
    end

    def success_message!(kind:)
      return unless is_navigational_format?
      set_flash_message(:notice, :success, kind: t("oauth.#{kind}"))
    end

    def connected_provider
      @connected_provider ||= ConnectedAccount.for_auth(auth)
    end

    def after_connect_redirect_path
      user_connected_providers_path
    end

    def connected_provider_params
      # Clean auth hash credentials
      auth_hash = auth.to_hash
      auth_hash.delete("credentials")
      auth_hash["extra"]&.delete("access_token")

      {
        provider: auth.provider,
        uid: auth.uid,
        access_token: auth.credentials.token,
        access_token_secret: auth.credentials.secret,
        expires_at: expires_at,
        refresh_token: auth.credentials.refresh_token,
        auth: auth_hash
      }
    end
  end
end
