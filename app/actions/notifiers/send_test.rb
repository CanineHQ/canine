class Notifiers::SendTest
  extend LightService::Action
  expects :notifier, :project, :user

  executed do |context|
    test_event = TestNotifier.new(project: context.project, notifier: context.notifier)

    if context.notifier.email?
      NotifierMailer.test_notification(context.user, test_event).deliver_now
    else
      payload = test_event.build_payload(context.notifier.provider_type)
      HTTParty.post(
        context.notifier.webhook_url,
        headers: { "Content-Type" => "application/json" },
        body: payload.to_json
      )
    end
  end
end
