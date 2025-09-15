class Users::SessionsController < Devise::SessionsController
  layout 'homepage', only: [ :new, :create, :account_login, :account_create ]
  before_action :load_account_from_slug, only: [ :account_login, :account_create ]

  def new
    super
  end

  def create
    super
  end

  def account_login
    self.resource = resource_class.new(sign_in_params)
    clean_up_passwords(resource)
    if @account.stack_manager.portainer?
      render "devise/sessions/portainer"
    else
      redirect_to new_user_session_path
    end
  end

  def account_create
    # If account has a stack manager, use Portainer authentication
    if @account.stack_manager.present?
      result = Portainer::Login.execute(
        username: params[:user][:email],
        password: params[:user][:password],
        account: @account,
      )

      if result.success?
        sign_in(result.user)

        # Auto-associate user with account if they sign in through account URL
        session[:account_id] = result.account.id

        redirect_to after_sign_in_path_for(result.user), notice: "Logged in successfully"
      else
        flash.now[:alert] = result.message
        self.resource = resource_class.new(sign_in_params)
        clean_up_passwords(resource)
        render 'devise/sessions/portainer'
      end
    else
      redirect_to new_user_session_path
    end
  end

  private

  def load_account_from_slug
    @account = Account.friendly.find(params[:slug])
  rescue ActiveRecord::RecordNotFound
    flash[:alert] = "Account not found"
    redirect_to new_user_session_path
  end
end
