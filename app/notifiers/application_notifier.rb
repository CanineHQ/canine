class ApplicationNotifier < Noticed::Event
  bulk_deliver_by :webhook, class: "BulkDeliveryMethods::ProjectWebhook"

  def project
    params[:project]
  end
end
