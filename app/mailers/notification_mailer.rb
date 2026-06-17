class NotificationMailer < ApplicationMailer
  def notify(to:, title:, text:, link: nil, link_text: nil)
    @title = title
    @text = text
    @link = link
    @link_text = link_text.presence || link

    mail(to: to, subject: title)
  end
end
