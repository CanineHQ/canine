class Avo::PasswordResetsController < Avo::ApplicationController
  def create
    user = User.find(params[:user_id])
    temp_password = generate_temp_password

    user.update!(
      password: temp_password,
      password_confirmation: temp_password,
      password_change_required: true
    )

    @credentials = {
      email: user.email,
      password: temp_password,
      login_url: main_app.new_user_session_url
    }

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to avo.resources_user_path(user), notice: "Password reset. Temp password: #{temp_password}" }
    end
  end

  private

  def generate_temp_password
    "#{SecureRandom.alphanumeric(8)}!#{SecureRandom.alphanumeric(4)}"
  end
end
