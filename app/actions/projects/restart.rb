class Projects::Restart
  extend LightService::Action
  expects :project

  executed do |context|
    context.project.services.running.each do |service|
      if service.web_service? || service.background_service?
        K8::Stateless::Deployment.new(service).restart
      end
    end
  end
end
