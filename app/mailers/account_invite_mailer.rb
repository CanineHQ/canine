class AccountInviteMailer < ApplicationMailer
  def invite(user, temp_password, account, login_url)
    @user = user
    @temp_password = temp_password
    @account = account
    @login_url = login_url

    mail(to: user.email, subject: "You've been invited to #{account.name} on Canine")
  end

  def added(user, account, login_url)
    @user = user
    @account = account
    @login_url = login_url

    mail(to: user.email, subject: "You've been added to #{account.name} on Canine")
  end
end
