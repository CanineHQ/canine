class ApplicationNotifier < Noticed::Event
  bulk_deliver_by :webhook, class: "BulkDeliveryMethods::ProjectWebhook"

  deliver_by :email do |config|
    config.mailer = "NotifierMailer"
    config.method = :notify
    config.if = -> { params[:project].notifiers.enabled.for_type(notification_type).exists?(provider_type: :email) }
  end

  def project
    params[:project]
  end

  def notification_type
    raise NotImplementedError
  end
end
