class Users::SessionsController < Devise::SessionsController
  layout 'homepage', only: [ :new, :create, :account_login, :account_create, :account_select ]
  before_action :require_no_authentication, only: [ :account_login, :account_select ]
  before_action :load_account_from_slug, only: [ :account_login, :account_create ]

  before_action :check_if_default_sign_in_allowed, only: [ :new ]
  before_action :check_if_account_select_allowed, only: [ :account_select ]

  def new
    super
  end

  def create
    super
  end

  def destroy
    account = current_account
    super do
      # If the account has a stack manager that provides authentication,
      # redirect to the custom account login URL after logout
      redirect_url = if account.custom_login?
        account_sign_in_path(account.slug)
      else
        root_path
      end

      respond_to do |format|
        format.html { redirect_to redirect_url, notice: "Signed out successfully." }
        format.json { render json: { redirect_url: redirect_url }, status: :ok }
      end
      return
    end
  end

  def account_select
    @accounts = Account.all.includes(:stack_manager)
  end

  def account_login
    self.resource = resource_class.new(sign_in_params)
    clean_up_passwords(resource)
    @sso_provider = @account.sso_provider if @account.sso_enabled?
    if @account.sso_provider&.ldap?
      render "devise/sessions/ldap"
    else
      render :new
    end
  end

  def account_create
    # If account has SSO provider with LDAP, use LDAP authentication
    if @account.sso_provider&.ldap?
      session[:ldap_account_id] = @account.id
      resource = warden.authenticate(:ldap_authenticatable, scope: :user)

      if resource
        sign_in(resource)
        session[:account_id] = @account.id
        redirect_to after_sign_in_path_for(resource), notice: "Logged in successfully"
      else
        flash[:alert] = "Invalid email or password"
        self.resource = resource_class.new(sign_in_params)
        clean_up_passwords(self.resource)
        render "devise/sessions/ldap"
      end
    else
      redirect_to new_user_session_path
    end
  end

  private

  def check_if_default_sign_in_allowed
    if Rails.application.config.account_sign_in_only
      redirect_to accounts_select_url
    end
  end

  def check_if_account_select_allowed
    unless Rails.application.config.account_sign_in_only
      redirect_to new_user_session_path
    end
  end

  def load_account_from_slug
    @account = Account.friendly.find(params[:slug])
  rescue ActiveRecord::RecordNotFound
    flash[:alert] = "Account not found"
    redirect_to new_user_session_path
  end
end
