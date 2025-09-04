class Projects::Restart
  extend LightService::Action
  expects :connection

  executed do |context|
    project = context.connection.project
    project.services.running.each do |service|
      if service.web_service? || service.background_service?
        K8::Stateless::Deployment.new(service).connect(context.connection).restart
      end
    end
  end
end
