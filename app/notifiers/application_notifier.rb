class ApplicationNotifier < Noticed::Event
  bulk_deliver_by :webhook, class: "DeliveryMethods::ProjectWebhook"

  def project
    params[:project]
  end
end
