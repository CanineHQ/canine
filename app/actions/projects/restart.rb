class Projects::Restart
  extend LightService::Action
  expects :project, :user

  executed do |context|
    context.project.services.running.each do |service|
      if service.web_service? || service.background_service?
        K8::Stateless::Deployment.new(service, context.user).restart
      end
    end
  end
end
